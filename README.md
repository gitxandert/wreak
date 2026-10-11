# Wreak

Write your intent the way it comes to mind.

When you work with a coding agent, you often already see the code in your
head. Then you end up describing it in English so the agent can turn it back
into the code you were picturing. That round trip is slow, and details get
lost. Wreak lets you skip it. Write the code you can see as code. Write the
logic you know the shape of as pseudo-code. Save prose for the parts you
actually want the agent to decide.

```
text:
	A tiny todo CLI. It MUST use only the standard library.

pseudo-code: --language python
	command add(title):
		items <- load()
		append {id: next_id(items), title, done: false} to items

code: --language python --file todo/storage.py
	PATH = pathlib.Path.home() / ".todo.json"
```

| Block | Use it when… | What the agent does | Editor color |
|---|---|---|---|
| `code:` | you can already see the exact lines | keeps them as written | teal, or the language's own highlighting with `--language` |
| `pseudo-code:` | you know the logic, but not every token | translates it faithfully | orange |
| `text:` | you know what you want, not how | makes the design decisions | violet |

Mix blocks at whatever granularity your thinking happens. A block can be one
line, a function signature, a loop body or a whole file. It's normal to switch
forms in the middle of a thought: an exact signature, then a sketched body, then
"handle errors however makes sense." Each block records how settled that piece
of the design is in your head, so the agent knows what to keep and what to
decide.

Type a header and press Enter. The editor indents the body with a tab. When
you type the next header on an indented line and press Enter, it snaps back to
column 0.

See [`docs/spec.md`](docs/spec.md) for the full grammar and semantics, and
[`examples/`](examples/) for complete files:
[`todo-cli.wreak`](examples/todo-cli.wreak) (a small app) and
[`rate-limiter.wreak`](examples/rate-limiter.wreak) (blocks interleaved
inside one feature).

## Repository layout

```
languages.json          single source of truth for --language names
scripts/build.mjs       generates grammars/maps from languages.json
editors/vscode/         VS Code extension (also Cursor, VSCodium, JetBrains via TextMate)
editors/vim/            Vim / Neovim plugin
skill/wreak/            agent skill (Claude Code, Codex, any SKILL.md-aware agent)
docs/spec.md            language specification
```

After editing `languages.json` or `docs/spec.md`, run `node scripts/build.mjs`.
Run the tests with `python3 -m unittest discover tests`.

## Install

The quickest way is the installer. It finds every supported editor and agent
on your machine and asks before each step:

```bash
./install.sh              # interactive
./install.sh --yes        # install everything without asking
./install.sh --uninstall  # remove everything it installed
```

For VS Code-family editors, it packages a `.vsix` with
`scripts/package_vsix.py` (no Node needed) and installs it with each editor's
CLI. Everything else is symlinked to this repo, so edits take effect without
reinstalling. Rerun the installer after changing the VS Code extension. If
something already exists at a target path, it is backed up, not overwritten.

The manual steps, per tool:

### VS Code, Cursor, Windsurf, VSCodium

Package and install a `.vsix` (use `cursor`, `codium` or `windsurf` in place of `code` as needed):

```bash
code --install-extension "$(python3 scripts/package_vsix.py)"
```

The extension sets the default colors through `editor.tokenColorCustomizations`.
If you already have your own `editor.tokenColorCustomizations`, yours replaces
the defaults. Copy the `textMateRules` you want from
`editors/vscode/package.json`. Header snap-back uses format-on-type, which the
extension turns on for `.wreak` files only.

### JetBrains IDEs

Go to **Settings → Editor → TextMate Bundles → +** and select `editors/vscode`.

### Vim

```bash
mkdir -p ~/.vim/pack/wreak/start && ln -s "$PWD/editors/vim" ~/.vim/pack/wreak/start/wreak
```

### Neovim

```bash
mkdir -p ~/.local/share/nvim/site/pack/wreak/start
ln -s "$PWD/editors/vim" ~/.local/share/nvim/site/pack/wreak/start/wreak
```

Or with lazy.nvim:

```lua
{
  "gitxandert/wreak",
  config = function(plugin)
    vim.opt.rtp:append(plugin.dir .. "/editors/vim")
    vim.filetype.add({ extension = { wreak = "wreak" } })
  end,
}
```

Code blocks use whichever Vim syntax files you have for their `--language`.
Add or override mappings with `let g:wreak_language_map = {'mylang': 'vimft'}`,
and override colors with `highlight wreakTextBlock guifg=...` (groups:
`wreakCode*`, `wreakPseudo*`, `wreakText*`).

### Agent skill

```bash
# Claude Code (personal; or use .claude/skills/ inside a project)
ln -s "$PWD/skill/wreak" ~/.claude/skills/wreak
# Codex
ln -s "$PWD/skill/wreak" ~/.codex/skills/wreak
```

Then ask the agent: *"Plan the app in spec.wreak"* or *"Build spec.wreak"*.
The skill parses the file with `skill/wreak/scripts/wreak_parse.py`, which uses
only Python's standard library, and treats each block according to its family.

## Not yet supported

- A tree-sitter grammar. It would add Neovim tree-sitter highlighting and
  injections, plus Helix and Zed support.
- Sublime Text and Emacs packages.
- A language server for diagnostics (stray text, empty blocks, unknown flags).
  The parser already reports these.
