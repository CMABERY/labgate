# labgate

Keeps a project's progression out of its product. Each repo gets a sibling
`<repo>.lab/` for plans, notes, experiments and handoffs; `main` receives only
gated, squash-merged promotions.

## What's included

```
labgate                  executable: `init`, `start`, `check`, `close` and `audit`
templates/
  repo.AGENTS.md         outer rules, installed as <repo>/AGENTS.md
  lab.AGENTS.md          inner rules, installed as <repo>.lab/AGENTS.md
  PROMOTE.md             the promotion procedure, installed into the lab
  handoff.md             builder → promoter declaration, installed as handoff/TEMPLATE.md
  pre-commit             installed as .git/hooks/pre-commit and pre-merge-commit: base = promotions only
tests/test_labgate.sh    exercises every subcommand in throwaway repos
```

Requires bash, git ≥ 2.31 and a GNU or BSD userland (grep, sed, awk, comm,
find). Nothing else. The repo root is taken to be the parent of the common
git directory, which is wrong for submodules and `GIT_DIR`-relocated repos;
those are unsupported. `PROMOTE.md` carries absolute paths: re-run `init`
after moving labgate or a lab.

## Usage

```bash
ln -s "$PWD/labgate" ~/.local/bin/labgate   # optional; the script also runs by path

cd ~/projects/foo        # an existing git repo
labgate init             # creates ../foo.lab, installs AGENTS.md, excludes .worktrees/,
                         # records the base branch, installs hooks that refuse ordinary
                         # commits and merges on main; safe to re-run

labgate start feature    # worktree at .worktrees/feature + ../foo.lab/handoff/feature.md
# build in the worktree; finish by filling in the handoff

labgate check feature    # exit 1 if the branch is not ready to promote
                         # (every command takes -C <dir> to run from elsewhere)
# then follow ../foo.lab/PROMOTE.md in a fresh session, which ends with
labgate close feature    # removes worktree, branch and handoff; needs the decision note

labgate audit            # exit 1 if main has drifted from the model (run it whenever)
```

`init` never overwrites an `AGENTS.md`. It always refreshes the lab's
`PROMOTE.md` and `handoff/TEMPLATE.md`, which labgate owns. The hook is skipped
when `core.hooksPath` is set or a foreign `pre-commit` exists; the promoter
commits with `LABGATE_PROMOTE=1`.

`check` lists its findings and exits 1 when, relative to the base branch, the
branch has any of:

- no handoff at `<lab>/handoff/<branch>.md`, one that still contains lines
  from the template, or one missing any of the template's fields
- added files or directories named plan(s), note(s), todo(s), changelog,
  scratch, debug, probe(s), tmp, wip, old, backup(s), copy/copies,
  experiment(s) or runs, at any depth, with any extension or suffix after a
  non-letter
- new top-level directories
- new top-level markdown other than `README.md`, `AGENTS.md` or `LICENSE*`
- added lines in non-markdown files containing TODO, FIXME, XXX, HACK,
  `debugger`, `breakpoint()`, `import pdb`, `pdb.<anything>`, `console.debug`,
  or DEBUG as a comment or string (`# DEBUG`, `"DEBUG"`; not `logging.DEBUG`
  or `#ifdef DEBUG`)
- more than 600 added lines (second argument overrides)

It also notes, without failing, a branch that removes nothing. Apart from the
handoff, these are look-twice triggers, not laws: the promoter deletes, or
justifies the finding in the decision note. A repo that legitimately keeps,
say, `CONTRIBUTING.md` records that in its own `AGENTS.md`; there is no
exemption config, on purpose.

The base branch is `LABGATE_BASE` if set, else `git config labgate.base`
(recorded by `init`), else `main`, else `master`.

`audit` applies the same taste to the base branch instead of a feature branch:
scaffolding-named or extra top-level markdown files tracked, `.worktrees/`
tracked, the main checkout not on the base branch, any commit on it since
`init` without the `Promoted-from:` trailer that PROMOTE.md step 5 writes
(fast-forwards, `--no-verify`, resets, rebases and cherry-picks all leave
commits without it), worktrees without handoffs, handoffs without worktrees,
and the lab, `AGENTS.md`, exclusion and hooks that `init` should have left
behind; it notes, without failing, a base branch whose `mergeOptions` is not
`--no-ff`. On a repo that predates labgate, its output is the migration list.

The guard is a local discipline aid, not branch protection: hooks and config
are per clone, `LABGATE_PROMOTE=1` and `--no-verify` are conscious bypasses,
and `git pull` into the base branch is refused like any other non-promotion
because the model assumes the base branch is produced here and pushed out.

## What you get

```
foo/                     product; main = one squash commit per promoted change
  AGENTS.md              outer rules (subtractive)
  .git/hooks/pre-commit  with pre-merge-commit: refuse commits on main unless LABGATE_PROMOTE=1
  .git/config            labgate.base, labgate.since, branch.main.mergeOptions=--no-ff
  .worktrees/<branch>/   where building happens; excluded via .git/info/exclude
foo.lab/                 progression; its own git repo, never merged, never shipped
  AGENTS.md              inner rules (permissive)
  PROMOTE.md             the gate
  handoff/  notes/  plans/  experiments/  runs/  prompts/
```

## The model

Three zones, one boundary: the lab and `main` never touch directly.

- **Build** in a worktree under the outer rules. Be fast and messy on the
  branch. End by declaring your own scaffolding in `handoff/<branch>.md`,
  while you still remember what it was.
- **Promote** in a fresh session that has the handoff but no attachment to
  the code. It deletes, inlines, fixes the README, tests, squash-merges, and
  writes a ten-line decision note to the lab. That note is where reasoning
  lives, so reasoning never needs a file in the repo.
- **Lab → repo** goes one way: rewrite, never move. Code born in the lab
  carries lab habits.

The sibling layout is deliberate. A directory outside the repo cannot be
committed by accident, and agents launched from the repo do not see it.

`labgate audit` catches the drift that leaves traces: non-promotion commits
on `main`, missing handoffs, scaffolding that slipped through. It cannot see
a builder session that started polishing; that one you notice when handoffs
get thinner.
