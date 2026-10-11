#!/usr/bin/env bash
# Install (or uninstall) Wreak for every editor and agent found on this machine.
# Asks before each major step.
#
#   ./install.sh               interactive install
#   ./install.sh --yes         answer yes to everything
#   ./install.sh --uninstall   remove everything this script installs
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASSUME_YES=0
UNINSTALL=0
for arg in "$@"; do
  case "$arg" in
    -y|--yes) ASSUME_YES=1 ;;
    -u|--uninstall) UNINSTALL=1 ;;
    -h|--help) sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

bold() { printf '\n\033[1m%s\033[0m\n' "$*"; }
info() { printf '  %s\n' "$*"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; }

# ask "question" -> 0 for yes. Reads from the terminal so it works when piped.
ask() {
  if [ "$ASSUME_YES" = 1 ]; then return 0; fi
  local reply
  printf '  %s [y/N] ' "$1"
  read -r reply </dev/tty || reply=""
  case "$reply" in [yY]|[yY][eE][sS]) return 0 ;; *) return 1 ;; esac
}

# link SOURCE TARGET: symlink, keeping a backup of anything already there.
link() {
  local src="$1" dst="$2"
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    ok "already linked: $dst"; return
  fi
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    warn "$dst already exists (not this repo's link)"
    if ! ask "Move it to $dst.bak.$(date +%s) and replace it?"; then info "skipped"; return; fi
    mv "$dst" "$dst.bak.$(date +%s)"
  fi
  mkdir -p "$(dirname "$dst")"
  ln -s "$src" "$dst"
  ok "linked $dst -> $src"
}

# unlink TARGET: remove only if it is our symlink.
unlink_ours() {
  local src="$1" dst="$2"
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    rm "$dst"; ok "removed $dst"
  elif [ -e "$dst" ]; then
    warn "$dst exists but is not this repo's link; leaving it"
  else
    info "not installed: $dst"
  fi
}

DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
CODEX_DIR="${CODEX_HOME:-$HOME/.codex}"
VIM_DST="$HOME/.vim/pack/wreak/start/wreak"
NVIM_DST="$DATA_HOME/nvim/site/pack/wreak/start/wreak"
CLAUDE_DST="$HOME/.claude/skills/wreak"
CODEX_DST="$CODEX_DIR/skills/wreak"
EXT_ID="gitxandert.wreak"
VSCODE_CLIS=(code code-insiders codium cursor windsurf)

found_vscode_clis() {
  local c
  for c in "${VSCODE_CLIS[@]}"; do command -v "$c" >/dev/null 2>&1 && echo "$c"; done
  return 0
}

# ------------------------------------------------------------------ uninstall
if [ "$UNINSTALL" = 1 ]; then
  bold "Uninstalling Wreak"
  for cli in $(found_vscode_clis); do
    if "$cli" --list-extensions 2>/dev/null | grep -qix "$EXT_ID"; then
      if ask "Uninstall the extension from $cli?"; then
        "$cli" --uninstall-extension "$EXT_ID" >/dev/null && ok "removed from $cli"
      fi
    fi
  done
  if ask "Remove the Vim, Neovim, Claude Code and Codex links (only ones pointing at this repo)?"; then
    unlink_ours "$REPO/editors/vim" "$VIM_DST"
    unlink_ours "$REPO/editors/vim" "$NVIM_DST"
    unlink_ours "$REPO/skill/wreak" "$CLAUDE_DST"
    unlink_ours "$REPO/skill/wreak" "$CODEX_DST"
  fi
  bold "Done."
  exit 0
fi

bold "Installing Wreak from $REPO"
info "You'll be asked before each step. Ctrl-C quits at any time."

# ------------------------------------------------------------------ 1. build
bold "1. Regenerate grammars from languages.json"
if command -v node >/dev/null 2>&1; then
  if ask "Run scripts/build.mjs (rewrites generated files inside the repo)?"; then
    node "$REPO/scripts/build.mjs" | sed 's/^/  /'
  else
    info "skipped; using the generated files already in the repo"
  fi
else
  info "node not found; using the generated files already in the repo"
fi

# ------------------------------------------------------------------ 2. VS Code family
bold "2. VS Code-family editors (VS Code, Insiders, VSCodium, Cursor, Windsurf)"
CLIS=$(found_vscode_clis)
if [ -z "$CLIS" ]; then
  info "none found on PATH"
else
  info "found: $(echo $CLIS)"
  VSIX=""
  for cli in $CLIS; do
    if ask "Install the Wreak extension into $cli?"; then
      if [ -z "$VSIX" ]; then
        VSIX="$(python3 "$REPO/scripts/package_vsix.py")"
        ok "packaged $VSIX"
      fi
      if "$cli" --install-extension "$VSIX" --force >/dev/null 2>&1; then
        ok "installed into $cli (reload its windows to activate)"
      else
        warn "$cli --install-extension failed; try: $cli --install-extension $VSIX"
      fi
    else
      info "skipped $cli"
    fi
  done
fi

# ------------------------------------------------------------------ 3. Vim
bold "3. Vim"
if command -v vim >/dev/null 2>&1; then
  if ask "Link the plugin into $VIM_DST?"; then
    link "$REPO/editors/vim" "$VIM_DST"
    grep -qs 'filetype plugin indent on\|syntax on' "$HOME/.vimrc" "$HOME/.vim/vimrc" ||
      info "note: Vim needs 'filetype plugin indent on' and 'syntax on' in your vimrc"
  else
    info "skipped"
  fi
else
  info "vim not found"
fi

# ------------------------------------------------------------------ 4. Neovim
bold "4. Neovim"
if command -v nvim >/dev/null 2>&1; then
  if ask "Link the plugin into $NVIM_DST?"; then
    link "$REPO/editors/vim" "$NVIM_DST"
    if grep -rqs 'lazy' "$CONFIG_HOME/nvim" --include='*.lua'; then
      warn "lazy.nvim detected: by default it ignores pack/*/start. Add this plugin spec instead:"
      info "  { dir = \"$REPO/editors/vim\", lazy = false }"
    fi
  else
    info "skipped"
  fi
else
  info "nvim not found"
fi

# ------------------------------------------------------------------ 5. Claude Code
bold "5. Claude Code skill"
if command -v claude >/dev/null 2>&1 || [ -d "$HOME/.claude" ]; then
  if ask "Link the skill into $CLAUDE_DST?"; then
    link "$REPO/skill/wreak" "$CLAUDE_DST"
  else
    info "skipped"
  fi
else
  info "Claude Code not found"
fi

# ------------------------------------------------------------------ 6. Codex
bold "6. Codex skill"
if command -v codex >/dev/null 2>&1 || [ -d "$CODEX_DIR" ]; then
  if ask "Link the skill into $CODEX_DST?"; then
    link "$REPO/skill/wreak" "$CODEX_DST"
  else
    info "skipped"
  fi
else
  info "Codex not found"
fi

# ------------------------------------------------------------------ 7. JetBrains
bold "7. JetBrains IDEs"
info "Not automated (IDE settings aren't safe to edit from outside)."
info "In the IDE: Settings → Editor → TextMate Bundles → + → $REPO/editors/vscode"

bold "Done. Try opening $REPO/examples/todo-cli.wreak"
info "Undo everything with: $0 --uninstall"
