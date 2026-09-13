#!/usr/bin/env bash
# Exercises labgate in throwaway repos.
set -euo pipefail

labgate="$(cd "$(dirname "$0")/.." && pwd)/labgate"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
fail() { echo "FAIL ${FUNCNAME[1]}: $*" >&2; exit 1; }

# fresh: a committed repo at $repo with labgate initialised; leaves cwd inside it
fresh() {
  repo="$work/foo"; lab="$work/foo.lab"
  rm -rf "$repo" "$lab"
  git init -q -b main "$repo" && cd "$repo"
  git config user.email test@example.com && git config user.name test
  printf '# foo\n' > README.md
  printf 'print(1)\n' > tool.py
  git add -A && git commit -qm init
  "$labgate" init >/dev/null
  git add AGENTS.md && LABGATE_PROMOTE=1 git commit -qm 'add outer rules' -m 'Promoted-from: init'
}
promote() { git checkout -q main && git merge -q --ff --squash "$1" >/dev/null && LABGATE_PROMOTE=1 git commit -qm "$1" -m "Promoted-from: $1"; }
branch()  { git checkout -q main && git checkout -qb "$1"; }
commit()  { git add -A && git commit -qm "$1"; }
handoff() { printf '# handoff: %s\nBehavior change: adds output.\nScaffolding left on the branch: none.\nUncertain: nothing.\nREADME.md: unchanged.\nVerified: tests.\n' "$1" > "$lab/handoff/$1.md"; }

test_invocation() {
  "$labgate" --help | grep -q '^usage:' || fail "--help should print usage on stdout and exit 0"
  ! "$labgate" >/dev/null 2>&1 || fail "no arguments should exit non-zero"
  fresh
  rm -rf "$lab"
  mkdir -p "$work/bin" "$work/bin2"
  ln -s "$labgate" "$work/bin/labgate"          # absolute symlink
  ln -s ../bin/labgate "$work/bin2/labgate"     # relative symlink to it
  "$work/bin2/labgate" init >/dev/null || fail "init through a symlink chain"
  [[ -f $lab/PROMOTE.md ]] || fail "templates not found through the symlink chain"
}

test_init() {
  fresh
  [[ -f $lab/AGENTS.md && -f $lab/PROMOTE.md && -f $lab/handoff/TEMPLATE.md ]] || fail "lab files missing"
  [[ -d $lab/.git ]] || fail "lab is not a git repo"
  grep -q 'foo.lab' "$lab/AGENTS.md" || fail "{{NAME}} not substituted"
  grep -q 'foo.lab' AGENTS.md || fail "repo AGENTS.md not installed"
  grep -q '`main`' AGENTS.md || fail "{{BASE}} not substituted"
  grep -qx '.worktrees/' .git/info/exclude || fail ".worktrees/ not excluded"
  [[ $(git config labgate.base) == main ]] || fail "labgate.base not set"
  [[ $(git config labgate.since) == $(git rev-parse main~1) ]] || fail "labgate.since is not the init-time head"
  [[ $(git config branch.main.mergeOptions) == --no-ff ]] || fail "mergeOptions not set"
  git config branch.main.mergeOptions --ff-only; "$labgate" init >/dev/null
  [[ $(git config branch.main.mergeOptions) == --ff-only ]] || fail "existing mergeOptions overwritten"
  git config branch.main.mergeOptions --no-ff

  printf 'custom\n' >> "$lab/AGENTS.md"
  printf 'custom\n' >> "$lab/PROMOTE.md"
  "$labgate" init >/dev/null
  grep -q custom "$lab/AGENTS.md" || fail "re-init clobbered the lab AGENTS.md"
  ! grep -q custom "$lab/PROMOTE.md" || fail "re-init did not refresh PROMOTE.md"
  grep -q "$labgate" "$lab/PROMOTE.md" || fail "{{LABGATE}} not substituted"
  grep -q "$lab" "$lab/PROMOTE.md" || fail "{{LAB}} not substituted"

  git init -q -b main "$work/empty" && ( cd "$work/empty" && git config user.email t@t && git config user.name t \
    && "$labgate" init >/dev/null && [[ -z $(git config labgate.since) ]] \
    && printf 'r\n' > README.md && git add -A && LABGATE_PROMOTE=1 git commit -qm init \
    && "$labgate" init >/dev/null && [[ $(git config labgate.since) == $(git rev-parse main) ]] ) \
    || fail "labgate.since not repaired on re-init of an initially empty repo"

  git worktree add -q .worktrees/wt -b wt main
  ( cd .worktrees/wt && "$labgate" init >/dev/null ) || fail "init from a worktree"
  ( cd / && "$labgate" -C "$repo/.worktrees/wt" init >/dev/null ) || fail "-C ignored"
  ! ( cd / && "$labgate" init 2>/dev/null ) || fail "outside a repo should fail"
  [[ ! -e $repo/.worktrees/wt.lab ]] || fail "init from a worktree resolved the wrong root"
}

test_hook() {
  fresh
  [[ -x .git/hooks/pre-commit ]] && grep -q 'Installed by labgate' .git/hooks/pre-commit || fail "hook not installed"
  printf 'x\n' >> README.md
  ! git commit -qam 'direct' 2>/dev/null || fail "commit on main should be refused"
  LABGATE_PROMOTE=1 git commit -qam 'promotion' || fail "LABGATE_PROMOTE=1 commit refused"
  branch side
  printf 'y\n' >> README.md
  git commit -qam 'on a branch' || fail "commit on a branch refused"
  git checkout -q main
  ! git merge -q side 2>/dev/null || fail "plain (fast-forwardable) merge into main should be refused"
  git merge --abort 2>/dev/null || true
  [[ $(git rev-parse main) != $(git rev-parse side) ]] || fail "fast-forward slipped through"
  ! git merge -q --squash side 2>/dev/null || fail "--squash alone should conflict with --no-ff"
  git merge -q --ff --squash side >/dev/null || fail "--ff --squash should stage the squash"
  git reset -q --hard
  LABGATE_PROMOTE=1 git merge -q --no-ff side || fail "LABGATE_PROMOTE=1 merge refused"

  printf '#!/bin/sh\nexit 0\n' > .git/hooks/pre-commit
  "$labgate" init >/dev/null
  ! grep -q 'Installed by labgate' .git/hooks/pre-commit || fail "foreign hook overwritten"
  rm .git/hooks/pre-commit .git/hooks/pre-merge-commit
  git config core.hooksPath "$work/hooks"
  "$labgate" init >/dev/null
  [[ ! -e .git/hooks/pre-commit && ! -e .git/hooks/pre-merge-commit ]] || fail "hook installed despite core.hooksPath"
  git config --unset core.hooksPath
}

test_start() {
  fresh
  out="$("$labgate" start feature)" || fail "start failed: $out"
  [[ -d .worktrees/feature ]] || fail "no worktree"
  [[ $(git -C .worktrees/feature symbolic-ref --short HEAD) == feature ]] || fail "worktree is not on the branch"
  grep -q '^# handoff: feature$' "$lab/handoff/feature.md" || fail "handoff not created from the template"
  ! "$labgate" start feature 2>/dev/null || fail "duplicate start should refuse"
  ! "$labgate" start feat/x 2>/dev/null || fail "slash in branch name should refuse"
  ! "$labgate" check feature >/dev/null 2>&1 || fail "unfilled handoff from start should fail check"
  rm -rf "$lab"
  ! "$labgate" start other 2>/dev/null || fail "start without a lab should refuse"
}

test_audit() {
  fresh
  "$labgate" audit >/dev/null || fail "fresh repo should pass audit"
  "$labgate" start feature >/dev/null
  rm "$lab/handoff/feature.md"
  printf 'h\n' > "$lab/handoff/ghost.md"
  printf 'x\n' > PLAN.md; printf 'n\n' > NOTES.md; printf 'c\n' > CONTRIBUTING.md
  git add -A && LABGATE_PROMOTE=1 git commit -qm 'drift'
  branch side; printf 'y\n' >> README.md; commit side; git checkout -q main
  LABGATE_PROMOTE=1 git merge -q --no-ff side
  rm .git/hooks/pre-merge-commit
  out="$("$labgate" audit 2>&1)" && fail "drifted repo should fail audit"
  for want in 'worktree without handoff: feature' 'handoff without worktree: ghost' PLAN.md NOTES.md CONTRIBUTING.md 'without a Promoted-from trailer' drift 'hooks missing'; do
    grep -q "$want" <<<"$out" || fail "did not report: $want"$'\n'"$out"
  done
  git config --unset branch.main.mergeOptions
  branch sneaky; printf 's\n' >> README.md; commit 'messy 1'; git checkout -q main
  git merge -q sneaky   # fast-forward: no hook can see it
  grep -q 'messy 1' <<<"$("$labgate" audit 2>&1)" || fail "fast-forwarded commit not reported"
  git config branch.main.mergeOptions --no-ff
  git checkout -qb other; printf 'x\n' > wip.md; git add -A; git commit -qm other
  out="$("$labgate" audit 2>&1)" || true
  grep -q "main checkout is on 'other', not main" <<<"$out" || fail "did not report the checkout being off main"
  ! grep -q wip.md <<<"$out" || fail "audit judged the checked-out branch instead of main"
  git checkout -q main
  git config labgate.since "$(git rev-parse main)"
  ! grep -q 'Promoted-from' <<<"$("$labgate" audit 2>&1)" || fail "commits before labgate.since reported"
  branch good; printf 'g\n' >> README.md; commit good; promote good
  ! grep -q 'Promoted-from' <<<"$("$labgate" audit 2>&1)" || fail "a promotion with the trailer was reported"
}

test_close() {
  fresh
  "$labgate" start feature >/dev/null
  ! "$labgate" close feature 2>/dev/null || fail "close without a decision note should refuse"
  printf 'note\n' > "$lab/notes/2026-01-01-my-feature.md"
  ! "$labgate" close feature 2>/dev/null || fail "another branch's note accepted as receipt"
  printf 'note\n' > "$lab/notes/undated-feature.md"
  ! "$labgate" close feature 2>/dev/null || fail "undated note accepted as receipt"
  printf 'note\n' > "$lab/notes/2026-01-01-feature.md"
  git worktree remove .worktrees/feature && git worktree add -q "$work/elsewhere" feature
  ! "$labgate" close feature 2>/dev/null || fail "close with the branch checked out elsewhere should refuse"
  git worktree remove "$work/elsewhere" && git worktree add -q .worktrees/feature feature
  printf 'x\n' > .worktrees/feature/untracked
  ! "$labgate" close feature 2>/dev/null || fail "close with a dirty worktree should refuse"
  rm .worktrees/feature/untracked
  "$labgate" close feature >/dev/null || fail "close failed"
  [[ ! -e .worktrees/feature ]] || fail "worktree still present"
  ! git rev-parse --verify -q feature >/dev/null || fail "branch still present"
  [[ ! -e $lab/handoff/feature.md ]] || fail "handoff still present"
}

test_check() {
  fresh
  branch messy
  printf 'x\n' > PLAN.md; mkdir utils; printf 'y\n' > utils/h.py; printf 'z\n' > scratch_probe.py
  printf 'print(2)  # T''ODO\n' >> tool.py   # split so this line does not match itself
  commit messy
  out="$("$labgate" check messy 3 2>&1)" && fail "messy branch should fail"
  for want in 'no handoff' PLAN.md scratch_probe.py utils 'markers in tool.py' 'adds 4 lines'; do
    grep -q "$want" <<<"$out" || fail "did not report: $want"$'\n'"$out"
  done
  cp "$lab/handoff/TEMPLATE.md" "$lab/handoff/messy.md"
  out="$("$labgate" check messy 2>&1)" && fail "unfilled handoff should fail"
  grep -q 'unfilled template lines' <<<"$out" || fail "did not report the unfilled handoff"
  printf '# handoff: messy\n' > "$lab/handoff/messy.md"
  out="$("$labgate" check messy 2>&1)" && fail "emptied handoff should fail"
  grep -q 'field missing or empty: Behavior change:' <<<"$out" || fail "did not report the emptied handoff"
  printf '# handoff: messy\nBehavior change: x.\nScaffolding left on the branch: none.\nUncertain: nothing.\nREADME.md: unchanged.\nVerified:   \n' > "$lab/handoff/messy.md"
  out="$("$labgate" check messy 2>&1)" && fail "blank field should fail"
  grep -q 'field missing or empty: Verified:' <<<"$out" || fail "did not report the blank field"

  branch clean
  printf 'print(3)\n' >> tool.py; printf 'c\n' > copyright.txt; printf 'l\n' > LICENSE.md
  printf 'see T''ODO list\n' >> README.md
  commit clean
  handoff clean
  out="$("$labgate" check clean 2>&1)" || fail "clean branch should pass:"$'\n'"$out"
  grep -q 'removes nothing' <<<"$out" || fail "no removes-nothing note"

  branch trim
  : > tool.py
  commit trim
  handoff trim
  out="$("$labgate" check trim 2>&1)" || fail "trim branch should pass:"$'\n'"$out"
  ! grep -q 'removes nothing' <<<"$out" || fail "removes-nothing note on a branch that removes"

  git branch -m main trunk
  LABGATE_BASE=trunk "$labgate" check clean >/dev/null || fail "LABGATE_BASE ignored"
  git config labgate.base trunk
  "$labgate" check clean >/dev/null || fail "labgate.base ignored"
  git config --unset labgate.base
  ! "$labgate" check clean 2>/dev/null || fail "missing base branch should fail"
  git branch -m trunk master
  "$labgate" check clean >/dev/null || fail "master fallback ignored"
}

for t in $(declare -F | awk '$3 ~ /^test_/ {print $3}'); do "$t"; done
echo ok
