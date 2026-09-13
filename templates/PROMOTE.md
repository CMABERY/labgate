# Promote a branch to {{BASE}}

Installed by `labgate init`; edits here are overwritten on the next init.

Run this in a fresh session, not the one that built the branch. Every command
below is absolute, so it does not matter where the session was launched.

    ROOT   = the main checkout of {{NAME}} (the parent of .worktrees/)
    LAB    = {{LAB}}
    BRANCH = the branch to promote
    labgate = {{LABGATE}}

Scope: subtract and verify. You may delete, inline, and fix `README.md`. You
may not add features, rename for taste, reformat, or refactor beyond inlining.

0. Read `$LAB/handoff/$BRANCH.md`. Run `labgate -C $ROOT check $BRANCH`. Every finding
   is either fixed in `$ROOT/.worktrees/$BRANCH` and committed there, or
   justified in the note in step 7.
1. `git -C $ROOT diff {{BASE}}...$BRANCH --stat`. For each file, one line on
   why a stranger needs it. No line ⇒ delete it.
2. Delete: everything the handoff declared as scaffolding; commented-out code;
   diagnostic logging; unused imports; helpers with one caller (inline them);
   abstractions with one concrete use (inline them).
3. `README.md`: does it describe what `{{BASE}}` will do after this merge?
   Fix it in place. Do not describe how it got there.
4. Run the tests. Run the tool once end to end. Record the exact commands.
5. `git -C $ROOT merge --squash $BRANCH && git -C $ROOT commit -m "<behavior change>"`.
   One commit; imperative; ≤72 characters. If the branch is genuinely two
   changes, split it and squash twice.
6. Rerun the tests on `{{BASE}}`.
7. Write ≤10 lines to `$LAB/notes/YYYY-MM-DD-$BRANCH.md`: decided, rejected,
   still uncertain, and any `check` finding you kept.
8. Only after step 6 passes:
   `git -C $ROOT worktree remove .worktrees/$BRANCH && git -C $ROOT branch -D $BRANCH && rm $LAB/handoff/$BRANCH.md`

Report: the commit hash on `{{BASE}}`, the commands run in steps 4 and 6, and
what was deleted.
