# Project Guidelines

## Purpose & Scope

Before changing a file, follow each rule file in `.claude/rules` whose `paths`
front matter matches it.

Record a convention that a change settles in this file or in a rule file, in the
same change, iff it helps AI work better enough to justify the context that it
uses, which restating what another file states (e.g., a workflow's matrix or a
script's arguments) never does.

When a change fixes a kind of problem that a tool can detect (e.g., via a Vale
rule in `.vale/scc`, or a SwiftLint custom rule), add a check for it in the same
change, so that `Scripts/check` catches each recurrence.

Never make a change that [Rejected Changes](#rejected-changes) lists; record
each rejected change there, with its reason.

Before changing anything, check its history (e.g., `git log -S`), so that no
change reverts an earlier one, unless the change says why the earlier one was
wrong.

## Minimum Versions

When bumping a minimum version, update every occurrence of it (e.g., in
`README.md`'s badges). `.xcode-version` names the preferred Xcode (the latest
stable one), not the minimum.

Set each dependency's `from:` in `Package.swift` to its oldest version with
which the package builds & passes all tests, as
`Scripts/test-dependency-versions` checks.

## Design

- Keep `CascadingConfiguration` re-exporting Swift Configuration, so that a
  package that depends on `CascadingConfiguration` needs no direct dependency on
  Swift Configuration
- Link each mention of a Swift Configuration symbol in DocC, except one that
  needs a trait (e.g., `JSONSnapshot`), which DocC cannot resolve, without a
  `Configuration/` prefix (e.g., ``` ``ConfigReader`` ```), which the re-export
  requires
- Declare no `platforms` in `Package.swift`; instead, mark each declaration that
  uses Swift Configuration with `@available(Configuration 1.0, *)` (each `@Test`
  function, never its suite, which Swift Testing rejects), so that a package
  that supports older platforms can depend on `CascadingConfiguration`

## Code From Other Projects

- Keep each file copied verbatim from another project (e.g., a vendored copy of
  an upstream API that is not public) in a `Vendored` folder of its target
  (e.g., `Sources/CascadingConfiguration/Vendored`), which the formatting &
  linting tools skip, so that it stays easy to compare with its upstream; record
  each change to such a file in its `Vendored copy` comment
- List each such file in `NOTICE.md`, with its upstream project & the
  attribution notices that the upstream's `NOTICE` file holds, and keep the text
  of each license under which such a file is available in `LICENSES` (e.g.,
  `LICENSES/Apache-2.0.txt`), as the license requires

## Git Workflow

- Label each pull request that breaks the API `breaking`, so that
  `api-breakage.yaml` skips it & its release notes list it under breaking
  changes
- Before committing:
  1. Add or edit tests for all new or changed behavior
  2. Repeatedly run `Scripts/format` until it makes no modifications, reviewing
     each run's modifications
  3. Repeatedly run `Scripts/check -A` & fix every failure until none are
     reported, skipping `Scripts/api-breakage` (via `-S api-breakage`) only for
     an intentional API break
  4. Manually check rules that linters do not enforce: Oxford commas; `second` &
     adjective `one` written as digits; `and` after a comma, which must separate
     distinct clauses or end a parenthetical or a nonrestrictive clause; &
     judgment-based rules (e.g., 1 `return` per function, `if` / `switch`
     expressions)
- **Commit messages:** Follow [commit message conventions](
    https://tbaggery.com/2008/04/19/a-note-about-git-commit-messages.html
  ), except end each subject line with a period (or with a colon iff the subject
  introduces a list)
- Never check or rewrite the formatting of an existing commit message (e.g., in
  a review); apply the commit message conventions only to a message being
  written
- Sign off every commit (`git commit -s`)

## File Naming

Give each file the longest standard extension for its file type that works for
its purpose (e.g., `.swiftlint.yml`, because `.swiftlint.yaml` does not work;
`ci.yaml`, because both work), except always use `.md` for Markdown.

## Content Formatting

- **Quoting:** Quote strings only when necessary, preferring the most literal
  format that works; among functionally equivalent quote syntaxes, prefer the
  visually lightest (e.g., single quotes over double quotes)
- **Text:** Applies to all prose, wherever it appears (e.g., comments, strings,
  markup, commit messages & documentation):
  - **Commas:** Use Oxford commas for lists
  - **Ampersands:** Prefer `&` to `and` (omit Oxford comma before `&`), except
    use `and` in `and/or`, after a comma that separates distinct clauses (but
    not in a list) & after a comma that ends a parenthetical or a nonrestrictive
    clause (e.g., `matches a value, which has text, and coerces it`)
  - **Quotes**: The quotation marks of a quote that ends a sentence (iff the
    whole sentence is not a quote) do not enclose the sentence's terminal
    punctuation mark
  - **Iff**: Use `iff` as `if & only if`
  - **Contractions:** Never use contractions (e.g., write `it is`, not `it's`),
    not even in test data
  - **Numbers:** Write numbers as digits (e.g., `at most 1`, `2nd`), except the
    pronoun `one` (e.g., `the last one wins`)

### Markdown Guidelines

These also govern Markdown inside DocC (`///`) comments.

- **Style:** GitHub-Flavored Markdown (GFM), ATX headings, backtick-fenced code
  blocks with language identifier, underscore emphasis, asterisk strong & hyphen
  bullets
- **HTML:** Use only GFM-supported HTML that has no native GFM equivalent
- **Cross-references:** Link a referenced file from relevant inline text, never
  from the file's name (a word naming a general concept, e.g., `README`, is not
  a file name, even if a file is named after it); reference a section only via a
  link whose URL fragment targets it, except in a code comment, which names the
  file & quotes the section's heading (e.g., `CLAUDE.md "Git Workflow"`)

## Refactoring Rules

Unless necessary for functionality, a fix, or a standards violation, never
reformat, rename, reorder, respace, or reword anything, never remove comments &
never refactor in a way that worsens the caller interface.

Refactoring should:

- Keep clean abstractions
- Inline a utility iff it is single-use
- Replace a utility iff the new version is more correct, performant, and/or
  simpler than the existing version, in descending order of priority

Apply every rename throughout the repository (e.g., specs, code identifiers,
comments, tests & docs), including to every name derived from the renamed one
(e.g., renaming a type renames the identifiers named after it).

## Rejected Changes

Each item is a change that was rejected, with its reason.
