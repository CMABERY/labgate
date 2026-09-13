#!/usr/bin/env bash
# Exercises `labgate init` and `labgate check` in a throwaway repo.
set -euo pipefail

labgate="$(cd "$(dirname "$0")/.." && pwd)/labgate"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

cd "$work"
git init -q -b main foo && cd foo
git config user.email test@example.com && git config user.name test
printf '# foo\n' > README.md
printf 'print(1)\n' > foo.py
git add -A && git commit -qm init

# init: lab sibling, its files, repo AGENTS.md, worktree exclusion; refuses to run twice
"$labgate" init >/dev/null
[[ -f ../foo.lab/AGENTS.md && -f ../foo.lab/PROMOTE.md && -f ../foo.lab/handoff/TEMPLATE.md ]] || fail "lab files missing"
[[ -d ../foo.lab/.git ]] || fail "lab is not a git repo"
grep -q 'foo.lab' ../foo.lab/AGENTS.md || fail "{{NAME}} not substituted in lab"
[[ -f AGENTS.md ]] && grep -q 'foo.lab' AGENTS.md || fail "repo AGENTS.md not installed"
grep -qx '.worktrees/' .git/info/exclude || fail ".worktrees/ not excluded"
! "$labgate" init 2>/dev/null || fail "second init should refuse"
git add AGENTS.md && git commit -qm 'add outer rules'

# init from inside a worktree resolves the main checkout
git worktree add -q .worktrees/wt -b wt main
( cd .worktrees/wt && ! "$labgate" init 2>/dev/null ) || fail "init from worktree should see the existing lab"

# check: a messy branch trips every rule
git checkout -qb messy
printf 'x\n' > PLAN.md
mkdir utils && printf 'y\n' > utils/h.py
printf 'z\n' > scratch_probe.py
printf 'print(2)\n' >> foo.py
git add -A && git commit -qm wip
out="$("$labgate" check messy 3 2>&1)" && fail "messy branch should fail"
for want in PLAN.md scratch_probe.py utils 'added 4 lines'; do
  grep -q "$want" <<<"$out" || fail "check did not report: $want"
done

# check: a clean branch passes; copyright.txt is not a "copy" file
git checkout -q main && git checkout -qb clean
printf 'print(3)\n' >> foo.py
printf 'c\n' > copyright.txt
git add -A && git commit -qm ok
"$labgate" check clean >/dev/null || fail "clean branch should pass"

# check: LABGATE_BASE
git branch -m main trunk
LABGATE_BASE=trunk "$labgate" check clean >/dev/null || fail "LABGATE_BASE not honoured"
! "$labgate" check clean 2>/dev/null || fail "missing base branch should fail"

echo ok
