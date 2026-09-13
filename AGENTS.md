# labgate

Canonical repo. `main` is the product. Every file in it is something a stranger
needs in order to use or modify this project.

The lab is `labgate.lab/`, a sibling of this repo's main checkout:
`../labgate.lab/` from the repo root, `../../../labgate.lab/` from a worktree.

- Scratch, plans, notes, probes, benchmark output: the lab, never here.
- No new files unless the task cannot be done in an existing one.
- No new top-level directories. No dependencies without asking.
- Replace ⇒ delete what was replaced. Update `README.md` in the same change.
- Work only in `.worktrees/<branch>`. Never edit `main` directly.
- A session is not finished until `<lab>/handoff/<branch>.md` exists
  (template: `<lab>/handoff/TEMPLATE.md`).
- Promotion to `main` is a separate session: `<lab>/PROMOTE.md`.
