#!/bin/sh
# install-skills.sh — install the asql Claude Code skills.
#
# Copies skills/asql and skills/asql-exec into your Claude skills directory
# (~/.claude/skills by default, or $CLAUDE_CONFIG_DIR/skills). Any existing
# copy is backed up to <name>.bak-<timestamp> before it is replaced.
#
# Usage:
#   ./install-skills.sh            install into the default location
#   ./install-skills.sh DIR        install into DIR/<skill>
#   ./install-skills.sh --uninstall remove the installed asql skills
set -eu

here=$(cd "$(dirname "$0")" && pwd)
src="$here/skills"

skills="asql asql-exec"

# Resolve target skills directory.
if [ "${1:-}" = "--uninstall" ]; then
	uninstall=1
	shift
else
	uninstall=0
fi

if [ $# -ge 1 ]; then
	dest="$1"
else
	config="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
	dest="$config/skills"
fi

if [ "$uninstall" = "1" ]; then
	for s in $skills; do
		if [ -e "$dest/$s" ]; then
			rm -rf "$dest/$s"
			echo "removed $dest/$s"
		else
			echo "not installed: $dest/$s"
		fi
	done
	exit 0
fi

if [ ! -d "$src/asql" ] || [ ! -d "$src/asql-exec" ]; then
	echo "error: skills/ not found next to this script ($src)" >&2
	exit 1
fi

mkdir -p "$dest"
stamp=$(date +%Y%m%d%H%M%S)

for s in $skills; do
	if [ -e "$dest/$s" ]; then
		mv "$dest/$s" "$dest/$s.bak-$stamp"
		echo "backed up existing $s -> $s.bak-$stamp"
	fi
	cp -R "$src/$s" "$dest/$s"
	echo "installed $s -> $dest/$s"
done

echo
echo "Done. Restart Claude Code (or run /doctor) so it picks up the new skills."
