# {{NAME}}

Canonical repo. `{{BASE}}` is the product. Every file in it is something a
stranger needs in order to use or modify this project.

The lab is `{{NAME}}.lab/`, a sibling of this repo's main checkout:
`../{{NAME}}.lab/` from the repo root, `../../../{{NAME}}.lab/` from a worktree.

- Scratch, plans, notes, probes, benchmark output: the lab, never here.
- No new files unless the task cannot be done in an existing one.
- No new top-level directories. No dependencies without asking.
- Replace ⇒ delete what was replaced. Update `README.md` in the same change.
- Work only in `.worktrees/<branch>`; `labgate start <branch>` creates it and
  a handoff to fill in. Never edit `{{BASE}}` directly.
- A session is not finished until `<lab>/handoff/<branch>.md` is filled in and
  `labgate check <branch>` reports nothing you cannot justify in the handoff.
- Promotion to `{{BASE}}` is a separate session: `<lab>/PROMOTE.md`.
