---
name: wreak
description: Interpret Wreak (.wreak) files, which mix `code:`, `pseudo-code:` and `text:` blocks, and turn them into an implementation plan or a working application. Use when the user references a .wreak file, pastes content with `code:` / `pseudo-code:` / `text:` block headers, or asks to plan or build something from a Wreak spec.
---

# Wreak

A Wreak file describes software at three levels of literalness. Each block
starts with a header at column 0, and its body is the tab-indented lines below
it:

```
text:                                   <- general intent; you decide the details
	...
pseudo-code: --language python          <- specific logic; translate it faithfully
	...
code: --language python --file app.py   <- exact lines; keep them as written
	...
```

The full grammar is in `references/spec.md`.

## Step 1: Parse

Always parse the file before you interpret it. Don't eyeball block boundaries:

```bash
python3 <skill-dir>/scripts/wreak_parse.py path/to/file.wreak --format outline   # quick read
python3 <skill-dir>/scripts/wreak_parse.py path/to/file.wreak                    # JSON
```

For pasted content, pipe it on stdin with `-` as the file argument. Show any
parser warnings to the user, such as stray top-level text, empty blocks or bad
flags. Don't silently ignore them.

## Step 2: Interpret each block by family

| Family | Treat it as | Latitude |
|---|---|---|
| `code:` | **Exact lines that must exist.** Put them in the output verbatim, in the block's `--language`, at `--file` if one is given. | Minimal. Fix only what is clearly necessary (obvious syntax errors, missing imports, wiring into surrounding code), and list every change in your summary. Never "improve" style, rename things or restructure. |
| `pseudo-code:` | **A specific design for code.** Translate it into real, idiomatic code in the target language, keeping its control flow, data shapes, ordering, edge cases and names. | Moderate. Adapt syntax and idioms, pick concrete types and library calls, and fill in obvious glue. Keep the logic as described. If the pseudo-code is wrong (a bug or impossible step), implement the evident intent and flag it. |
| `text:` | **Intent, requirements and context.** Goals, features, UX, constraints, architecture, preferences. | High. Make the design decisions needed to meet them. Treat capitalized MUST, NEVER, ALWAYS and SHOULD as hard or soft requirements. |

Other rules:

- **Precedence on a specific detail:** code > pseudo-code > text. Text still sets
  the overall goals. If a code block contradicts an explicit text requirement,
  raise the conflict and don't pick one silently.
- **Equal rank:** the later block refines the earlier one.
- **Order is narrative**, not execution order. Assemble the program logically.
- **Target language:** use the block's `--language` first. Otherwise infer it
  from nearby code blocks, then from the text. If nothing decides it, choose a
  sensible default and say so, or ask if the choice matters.
- **`--file PATH`:** put that block's output at PATH. Several blocks may target
  the same file. Merge them in document order unless the logic dictates
  otherwise.
- **Other flags** (`--name x`, `--optional`, ...) are author metadata. Interpret
  them by their plain meaning.
- **`#` comments** at column 0 are notes for humans. Ignore them as instructions.
- **Implicit text** (stray top-level lines) counts as `text:`.

## Step 3: Decide the deliverable

- If the user asks for a **plan** (or the request is ambiguous and the spec is
  large), produce the plan described below and stop.
- If the user asks to **build**, **implement** or **make** it, produce the
  working application, then the summary described below.

### Plan format

1. **Summary.** What will be built, in which language(s) and stack.
2. **Block map.** For every block: `[n] kind Lx-y -> where it lands`
   (file/module/function), and for code blocks whether they are used verbatim.
3. **Decisions.** Choices you made to satisfy `text:` blocks (libraries,
   architecture, data storage), each with a one-line reason.
4. **File tree.** The files to create or modify.
5. **Open questions and conflicts.** Contradictions, gaps and anything that
   needs the author.

### Build rules

- Check the build: compile, run or test as the stack allows. Report failures
  honestly.
- After building, give the block map again, marked done, plus every deviation
  from a `code:` block and every flagged `pseudo-code:` problem.
- Don't add large features that no block asks for. Small necessary glue
  (entry points, config, dependency manifests) is expected.

## Writing Wreak for the user

If the user asks you to draft or edit a .wreak file:

- Headers go at column 0. Body lines are indented with exactly one tab.
- Use `text:` for goals, `pseudo-code:` for the logic they care about, and
  `code:` only for lines they want kept literally.
- Run the parser afterwards to confirm the file has no warnings.
