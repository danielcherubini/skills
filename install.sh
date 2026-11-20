#!/usr/bin/env bash
set -euo pipefail

# dotagents — install symlinks from ~/.agents/ into tool config directories
# Run from anywhere: ~/.agents/install.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ "$SCRIPT_DIR" != "$HOME/.agents" ]]; then
    echo "Error: this script must live in ~/.agents/"
    exit 1
fi

# Each line: destination  source (relative to ~/.agents/)
# NOTE: pi/, claude/, opencode/ configs now live in ~/dotfiles/ and are
# managed by dotfiles/install.conf.yaml (dotbot). Only skills/ and agents/
# remain here.
declare -A LINKS=(
    ["~/.claude/skills"]="skills"
    ["~/.config/opencode/agents"]="agents"
)

link() {
    local dest="$1"
    local src="$2"
    local abs_src="$SCRIPT_DIR/$src"
    dest="${dest/#\~/$HOME}"

    if [[ ! -e "$abs_src" ]]; then
        echo "SKIP  $dest (source not found: $src)"
        return
    fi

    if [[ -L "$dest" ]]; then
        local current_target
        current_target="$(readlink -f "$dest" 2>/dev/null || true)"
        if [[ "$current_target" == "$abs_src" ]]; then
            echo "OK    $dest"
            return
        fi
        echo "RELINK $dest -> $abs_src"
        rm "$dest"
    elif [[ -e "$dest" ]]; then
        echo "SKIP  $dest (exists, not a symlink)"
        return
    fi

    local dir
    dir="$(dirname "$dest")"
    mkdir -p "$dir"
    ln -s "$abs_src" "$dest"
    echo "LINK  $dest -> $abs_src"
}

echo "Installing dotagents symlinks..."
for dest in "${!LINKS[@]}"; do
    link "$dest" "${LINKS[$dest]}"
done
echo "Done."
