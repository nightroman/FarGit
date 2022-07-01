# FarGit Release Notes

## v0.4.2

Fix missed/empty error messages from git.

## v0.4.1

Get branch panel commit messages in the background.

Branch panel current branch:

- set current in the panel on opening
- show with `*` (clean) or `>` (changes)

Branch panel modes:

- `[Ctrl0]` default
- `[Ctrl9]` full screen

## v0.4.0

Show commit messages for local branches in the description column.

## v0.3.0

Delete selected remote branches as well as local.

## v0.2.1

Show remote branches as normal (not hidden) files, #1.

## v0.2.0

Added the new command `Open-FarGitStash` which opens the panel with stashes.
You can view `[F3]`, create `[F7]`, delete `[Del]`/`[F8]`, and apply `[Enter]` stashes.

Removed the command `Invoke-FarGitStashShow`.
It is replaced with more useful stash panel.

## v0.1.4

Branch panel

- `[F3]` ~ Open gitk with the current panel branch.
- Do not show `remotes/origin/HEAD -> ...`.
- Amend remote branch check on `[Enter]`.

## v0.1.3

Branch panel

- Amend branch name parsing (fix `(no branch)`).

## v0.1.2

Branch panel

- Amend the check for hidden/remote branches.

## v0.1.1

Branch panel

- Use `[Enter]` to checkout the current panel branch, including remote (hidden).

## v0.1.0

Moved from [GitHub gist](https://gist.github.com/nightroman/1d4806e4bcd2fae1b852).

New command `Open-FarGitBranch` to show branches in the panel.
You can create, delete, rename branches.
