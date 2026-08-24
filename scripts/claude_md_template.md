# CLAUDE.md Template

The canonical contract every `CLAUDE.md` in this repo is checked against by
`check_claude_md.dart`. Edit **this** file to change the contract — the
checker parses it and it is the single source of truth.

The `## ` headings below are the **required sections**, in the required order:

## Related Guides

## Verification

The `coverage:` lines below are the **file globs** (relative to each
CLAUDE.md's own directory) whose every match must be displayed in that
CLAUDE.md:

coverage: lib/**/*.dart
coverage: bin/**/*.dart
coverage: *.dart

### How the checker matches

- **Sections**: a required heading matches a document heading whose text
  starts with it, ignoring a leading `N. ` number — so `## Verification`
  also satisfies `## Verification Commands` and `## 3. Verification Commands`.
  Required sections must appear in the order listed above.
- **Coverage**: every matched file must appear as a *dedicated entry* — the
  file's path (relative to the CLAUDE.md's directory) at the start of a
  heading or bullet line, e.g. `` ### `lib/src/foo.dart` `` or
  `` - `lib/src/foo.dart` — what it does``. A passing mention inside prose
  does not count: the point is a guide that *displays* every underlying
  source file with an explanation of what it contains, not one that merely
  name-drops them.
- `lib/**/*.dart` and `bin/**/*.dart` are recursive; `*.dart` covers only
  the CLAUDE.md's own directory, not subdirectories.
- Every document must also have a top-level `# ` title.
