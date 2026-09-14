#!/bin/sh
# install.sh — download the latest asql release and put it on your PATH.
#
#   curl -fsSL https://cuiqanalytics.github.io/asql/install.sh | sh
#
# No root needed: unpacks to ~/.local/lib/asql and symlinks ~/.local/bin/asql to the
# bundled launcher (which sets LIBDUCKDB_DIR to the copy right next to it — see
# README.md's "What's in the download"). Re-running just replaces the previous install.
set -eu

repo="cuiqanalytics/asql"
lib_dir="${HOME}/.local/lib/asql"
bin_dir="${HOME}/.local/bin"
url="https://github.com/${repo}/releases/latest/download/asql-cli-linux-x86_64.tar.gz"

echo "Downloading ${url}"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
curl -fsSL "$url" | tar xz -C "$tmp"

rm -rf "$lib_dir"
mkdir -p "$(dirname "$lib_dir")"
mv "$tmp/asql-cli-linux-x86_64" "$lib_dir"

mkdir -p "$bin_dir"
ln -sf "$lib_dir/asql" "$bin_dir/asql"

echo "Installed to $lib_dir"
echo "Linked $bin_dir/asql -> $lib_dir/asql"

case ":$PATH:" in
	*":$bin_dir:"*) ;;
	*) echo "Add $bin_dir to your PATH (e.g. in ~/.bashrc): export PATH=\"$bin_dir:\$PATH\"" ;;
esac

"$bin_dir/asql" --version
