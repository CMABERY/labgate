# labgate

Keeps a project's progression out of its product. Each repo gets a sibling
`<repo>.lab/` for plans, notes, experiments and handoffs; `main` receives only
gated, squash-merged promotions.

## What's included

```
labgate                  executable: `init`, `start` and `check`
templates/
  repo.AGENTS.md         outer rules, installed as <repo>/AGENTS.md
  lab.AGENTS.md          inner rules, installed as <repo>.lab/AGENTS.md
  PROMOTE.md             the promotion procedure, installed into the lab
  handoff.md             builder → promoter declaration, installed as handoff/TEMPLATE.md
tests/test_labgate.sh    exercises init and check in a throwaway repo
```

Requires bash, git ≥ 2.28 and GNU coreutils. Nothing else.

## Usage

```bash
ln -s "$PWD/labgate" ~/.local/bin/labgate   # optional; the script also runs by path

cd ~/projects/foo        # an existing git repo
labgate init             # creates ../foo.lab, installs AGENTS.md, excludes .worktrees/,
                         # records the base branch; safe to re-run

labgate start feature    # worktree at .worktrees/feature + ../foo.lab/handoff/feature.md
# build in the worktree; finish by filling in the handoff

labgate check feature    # exit 1 if the branch is not ready to promote
                         # (every command takes -C <dir> to run from elsewhere)
# then follow ../foo.lab/PROMOTE.md in a fresh session
```

`init` never overwrites an `AGENTS.md`. It always refreshes the lab's
`PROMOTE.md` and `handoff/TEMPLATE.md`, which labgate owns.

`check` lists its findings and exits 1 when, relative to the base branch, the
branch has any of:

- no handoff at `<lab>/handoff/<branch>.md`, or one that still contains lines
  from the template
- added files named plan, note(s), todo, changelog, scratch, debug, probe, tmp,
  wip, old, backup or copy, with any extension or suffix after a non-letter
- new top-level directories
- new top-level markdown other than `README.md`, `AGENTS.md` or `LICENSE*`
- added lines in non-markdown files containing TODO, FIXME, XXX, HACK, DEBUG,
  `breakpoint()`, `pdb`, `debugger` or `console.debug`
- more than 600 added lines (second argument overrides)

It also notes, without failing, a branch that removes nothing. Apart from the
handoff, these are look-twice triggers, not laws: the promoter deletes, or
justifies the finding in the decision note.

The base branch is `LABGATE_BASE` if set, else `git config labgate.base`
(recorded by `init`), else `main`, else `master`.

## What you get

```
foo/                     product; main = one squash commit per promoted change
  AGENTS.md              outer rules (subtractive)
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

Watch for: commits on `main` that are not promotions (`git log --first-parent
main` should read like a changelog), builder sessions that start polishing,
and missing handoffs. Each means the wrong zone's rules were loaded.
