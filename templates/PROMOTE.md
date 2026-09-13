# Promote a branch to main

Run this in a fresh session launched from `.worktrees/<branch>` in the
`{{NAME}}` repo. BRANCH is the branch name. LAB is `../../../{{NAME}}.lab`.

Scope: subtract and verify. You may delete, inline, and fix `README.md`.
You may not add features, rename for taste, reformat, or refactor beyond
inlining.

0. Read `$LAB/handoff/$BRANCH.md`. Run `labgate check $BRANCH`.
1. `git diff main...$BRANCH --stat`. For each file, one line on why a stranger
   needs it. No line ⇒ delete it.
2. Delete: everything the handoff declared as scaffolding; anything the check
   flagged; commented-out code; TODO comments; diagnostic logging; unused
   imports; helpers with one caller (inline them); abstractions with one
   concrete use (inline them).
3. `README.md`: does it describe what `main` will do after this merge? Fix it
   in place. Do not describe how it got there.
4. Run the tests. Run the tool once end to end. Record the exact commands.

Steps 5–8 run from the main checkout: `cd ../..`.

5. `git merge --squash $BRANCH && git commit -m "<behavior change>"`. One
   commit; the message is imperative and ≤72 characters. If the branch is
   genuinely two changes, split it and squash twice.
6. Rerun the tests on `main`.
7. Write ≤10 lines to `$LAB/notes/YYYY-MM-DD-$BRANCH.md`: decided, rejected,
   still uncertain. Then delete `$LAB/handoff/$BRANCH.md`.
8. Only after step 6 passes:
   `git worktree remove .worktrees/$BRANCH && git branch -D $BRANCH`.

Report: the commit hash on `main`, the commands run in steps 4 and 6, and what
was deleted.
