# labgate

Keeps a project's progression out of its product.

Every repository gets a sibling `<repo>.lab/` for plans, notes, probe
scripts, sample data and handoffs. `main` receives only squash-merged
promotions, each gated by a check and made in a session other than the one
that built it. Built for solo and agent-driven development, where the session
that wrote the code is the worst judge of what to delete.

## Why

Adding is cheaper than removing, and every tool that helps you build helps
you add. Plans, probe scripts, debug prints and notes to self end up in the
repo because they feel too useful to throw away and there is nowhere else to
put them. Agents make it worse: a builder session remembers why every line
exists and will defend all of it.

labgate gives the progression a home that is not the product, and puts a
context reset between building and merging. The builder declares its own
scaffolding while it still remembers what it was; a fresh promoter deletes it
without attachment. Everything else in the tool exists to make skipping that
boundary a visible choice instead of the default.

## The loop

```
labgate start feature     worktree at .worktrees/feature, plus a handoff to fill in
  build                   in the worktree, fast and messy; end by filling in the handoff
labgate check feature     exit 1 until the branch is fit to promote
  promote                 in a NEW session, following <repo>.lab/PROMOTE.md: delete,
                          inline, fix the README, test, squash onto main, write a
                          ten-line decision note to the lab
labgate close feature     remove the worktree, branch and handoff (needs that note)
labgate audit             any time: has main drifted from the model?
```

The handoff is the artefact that crosses the boundary:

```
# handoff: feature
Behavior change: `--top N` lists the N most common fields under the summary.
Scaffolding left on the branch: probe_schema.py, PLAN.md, a DEBUG print in main().
Uncertain: main() now parses argv; nothing else called it.
README.md: not updated; --top needs documenting.
Verified: python3 tests/test_tool.py → ok; ran the tool on a sample file.
```

## Install

```bash
git clone https://github.com/CMABERY/labgate ~/src/labgate
ln -s ~/src/labgate/labgate ~/.local/bin/labgate     # or run it by path
```

```
labgate                  executable: init, start, check, close, audit
templates/
  repo.AGENTS.md         outer rules, installed as <repo>/AGENTS.md
  lab.AGENTS.md          inner rules, installed as <repo>.lab/AGENTS.md
  PROMOTE.md             the promotion procedure, installed into the lab
  handoff.md             builder → promoter declaration, installed as handoff/TEMPLATE.md
  pre-commit             installed as .git/hooks/pre-commit and pre-merge-commit
tests/test_labgate.sh    exercises every subcommand in throwaway repos
```

Requires bash, git ≥ 2.31 and a GNU or BSD userland (grep, sed, awk, comm,
find). Nothing else. Developed and tested on Linux; written without GNU-only
flags, not yet exercised on macOS or BSD.

## Usage

```bash
cd ~/projects/foo        # an existing git repo
labgate init             # creates ../foo.lab, installs AGENTS.md, excludes .worktrees/,
                         # records the base branch, installs hooks that refuse ordinary
                         # commits and merges on main; safe to re-run
labgate start <branch>
labgate check <branch> [max-added-lines]
labgate close <branch>
labgate audit
```

Every command takes `-C <dir>` first, git-style, and works from anywhere
inside the repo or one of its worktrees. The base branch is `LABGATE_BASE` if
set, else `git config labgate.base` (recorded by `init`), else `main`, else
`master`.

`init` never overwrites an `AGENTS.md`. It always refreshes the lab's
`PROMOTE.md` and `handoff/TEMPLATE.md`, which labgate owns. Hooks are skipped
when `core.hooksPath` is set or a foreign hook exists. The promoter commits
with `LABGATE_PROMOTE=1`.

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

## What check and audit look for

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
justifies the finding in the decision note.

`audit` applies the same taste to the base branch: scaffolding-named or extra
top-level markdown files tracked, `.worktrees/` tracked, the main checkout
not on the base branch, any commit on it since `init` without the
`Promoted-from:` trailer that PROMOTE.md step 5 writes (fast-forwards,
`--no-verify`, resets, rebases and cherry-picks all leave commits without
it), worktrees without handoffs, handoffs without worktrees, and the lab,
`AGENTS.md`, exclusion and hooks that `init` should have left behind. It
notes, without failing, a base branch whose `mergeOptions` is not `--no-ff`.
On a repo that predates labgate, its output is the migration list.

## Limits

- A local discipline aid, not branch protection. Hooks and config are per
  clone; `LABGATE_PROMOTE=1` and `--no-verify` are conscious bypasses; `git
  pull` into the base branch is refused like any other non-promotion, because
  the model assumes the base branch is produced here and pushed out.
- The repo root is the parent of the common git directory. Submodules and
  `GIT_DIR`-relocated repos are unsupported.
- Branch names may not contain `/`.
- `PROMOTE.md` carries absolute paths; re-run `init` after moving labgate or
  a lab.
- The rules are heuristics on names and markers. A well-named file full of
  speculative abstraction passes; that is what the promoter is for.
- No exemption config, on purpose. A repo that legitimately keeps
  `CONTRIBUTING.md` says so in its own `AGENTS.md`; a promoter that keeps a
  flagged finding says why in the decision note.

## Development

labgate is developed with labgate. Its own lab is not published. Its history
is the changelog (`git log --first-parent main`); every commit there carries a
`Promoted-from:` trailer naming the branch it was squashed from.

Tests: `tests/test_labgate.sh`.

## Status

Early and opinionated. Used by its author on personal repos. The mechanical
parts are tested; the premise that a fresh promoter produces cleaner repos
than a builder polishing its own work is a design bet, not a measured result.

## License

MIT, see `LICENSE`.
