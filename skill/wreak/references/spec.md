# Wreak Language Specification (v0.1)

Wreak is a pseudo-language for describing software to a coding agent. A
`.wreak` file is a sequence of **blocks**. Each block belongs to one of three
families, and the family tells the reader (human or agent) how literally to
take its contents:

| Family        | Header          | Meaning                                         | Binding strength |
|---------------|-----------------|-------------------------------------------------|------------------|
| code          | `code:`         | Exact lines of code that should exist           | Highest          |
| pseudo-code   | `pseudo-code:`  | Specific ideas for code: logic, structure, flow | Medium           |
| text          | `text:`         | General intent, requirements, descriptions      | Lowest (latitude)|

## 1. File structure

```
file      := (blank | comment | block | stray)*
block     := header NEWLINE body
header    := KIND ":" (WS flag)* WS* EOL          -- must start at column 0
KIND      := "code" | "pseudo-code" | "pseudocode" | "text"
flag      := LONGFLAG (("=" | WS+) VALUE)? | SHORTFLAG WS+ VALUE
body      := (indented-line | blank)*
indented-line := TAB anything EOL                 -- one leading tab
comment   := "#" anything EOL                     -- at column 0
```

- A **header** is a line that starts at column 0 with a family keyword
  followed immediately by `:` and then whitespace or end of line.
  `code:stuff` is *not* a header.
- The **body** is every following line that is blank or begins with
  whitespace. The body ends at the next line that starts with a non-whitespace
  character (usually the next header).
- Body lines are indented by **one tab**. Editors insert it automatically after
  you press Enter on a header line, and keep it on following lines. The parser
  removes exactly one leading tab from each body line, so nested indentation
  inside the body is preserved. For leniency, a body indented only with spaces
  has its common leading whitespace removed instead.
- Trailing blank lines of a body are dropped.
- **Comments** are column-0 lines starting with `#`. They are notes for humans
  and are ignored by agents. (A `#` inside a body is ordinary body content.)
- **Stray lines** are column-0 lines that are neither headers nor comments.
  They are treated as an implicit `text:` block, and the parser emits a warning.

## 2. Flags

Flags appear on the header line after the colon.

| Flag                         | Applies to | Meaning |
|------------------------------|------------|---------|
| `--language NAME`, `-l NAME` | any        | On `code:` it selects syntax highlighting and fixes the language of the lines. On `pseudo-code:`/`text:` it hints the target language. |
| `--file PATH`, `-f PATH`     | any        | Where the result should live (target file or directory). |
| `--KEY VALUE` / `--KEY`      | any        | Free-form metadata, passed to the agent unchanged (for example `--name auth-flow`, `--optional`). |

`NAME` is a lowercase language id or alias from [`languages.json`](../scripts/languages.json)
(for example `python`, `py`, `ts`, `rust`, `c++`). Unknown names are allowed.
They get generic code highlighting, and agents still read them as the language
of the block.

## 3. Semantics (how agents interpret blocks)

1. **code** blocks are *prescriptive*. The lines should appear in the output
   essentially as written. Agents may only make minimal, clearly necessary
   changes (fixing obvious syntax errors, adjusting imports, fitting the code
   into surrounding code) and must report any change they make.
2. **pseudo-code** blocks are *specific but not literal*. Agents translate them
   into real code in the target language, keeping the described logic,
   control flow, data shapes and names unless that would be unidiomatic or
   wrong.
3. **text** blocks are *descriptive*. They state goals, constraints, behavior,
   UX, architecture or preferences. Agents make the design decisions needed to
   meet them.

Precedence when blocks conflict on a specific detail: **code > pseudo-code >
text**. Text still governs overall goals and constraints. If a code block
contradicts an explicit text requirement, the agent raises it rather than
silently picking one. When blocks are of equal rank, the later block refines
the earlier one. Block order is narrative and does not imply execution order.

## 4. Example

```
# Todo CLI. Comments like this one are for humans only.
text:
	A tiny command-line todo manager. Store items in ~/.todo.json.
	Keep dependencies to the standard library.

pseudo-code: --language python
	command add(title):
		items <- load()
		append {id: next_id(items), title, done: false} to items
		save(items)

code: --language python --file todo/storage.py
	import json, pathlib

	PATH = pathlib.Path.home() / ".todo.json"

	def load():
	    return json.loads(PATH.read_text()) if PATH.exists() else []
```
