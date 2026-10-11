# Wreak

A pseudo-language for describing software to coding agents. A `.wreak` file
mixes three block families. Each one tells the agent how literally to take
what you wrote:

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

| Block | Meaning to the agent | Editor color |
|---|---|---|
| `code:` | Exact lines that must exist | teal, or the language's own highlighting with `--language` |
| `pseudo-code:` | A specific design for code, translated faithfully | orange |
| `text:` | General intent and requirements; the agent decides the details | violet |

Type a header and press Enter. The editor indents the body with a tab. When
you type the next header on an indented line and press Enter, it snaps back to
column 0.

See [`docs/spec.md`](docs/spec.md) for the full grammar and semantics, and
[`examples/todo-cli.wreak`](examples/todo-cli.wreak) for a complete example.

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
