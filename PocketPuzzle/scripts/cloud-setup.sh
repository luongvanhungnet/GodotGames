#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
version="$(tr -d '\r\n' < .godot-version)"
if [[ "$(uname -s)" != Linux || "$(uname -m)" != x86_64 ]]; then
  echo 'Cloud setup requires Linux x86_64.' >&2
  exit 1
fi
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo 'Invalid .godot-version; expected major.minor.patch.' >&2
  exit 1
fi
for command in curl unzip; do
  command -v "$command" >/dev/null || { echo "Missing prerequisite: $command" >&2; exit 1; }
done
tools_dir="$PWD/.godot/cloud-tools"
mkdir -p "$tools_dir"
archive="$tools_dir/godot.zip"
curl --fail --location --retry 3 "https://github.com/godotengine/godot/releases/download/${version}-stable/Godot_v${version}-stable_linux.x86_64.zip" -o "$archive"
unzip -o "$archive" -d "$tools_dir"
chmod +x "$tools_dir/Godot_v${version}-stable_linux.x86_64"
ln -sf "$tools_dir/Godot_v${version}-stable_linux.x86_64" "$tools_dir/godot"
"$tools_dir/godot" --version
if [[ "$("$tools_dir/godot" --version)" != "$version.stable."* ]]; then
  echo 'Downloaded engine version does not match the pin.' >&2
  exit 1
fi
"$tools_dir/godot" --headless --path . --editor --import --quit
"$tools_dir/godot" --headless --path . --script tests/smoke.gd
"$tools_dir/godot" --headless --path . --script tests/gameplay.gd
"$tools_dir/godot" --headless --path . --script tests/records.gd
"$tools_dir/godot" --headless --path . --quit-after 5
