#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
ICON_TEMP="$(mktemp -d "${TMPDIR:-/tmp}/macfalcon-icon.XXXXXX")"
trap 'rm -rf "$ICON_TEMP"' EXIT
for size in 16 32 64 128 256 512 1024; do
  sips -z "$size" "$size" Assets/AppIcon.png --out "$ICON_TEMP/$size.png" >/dev/null
done
# An ICNS file can contain PNG chunks for modern macOS icon sizes.
python3 - "$ICON_TEMP" Assets/AppIcon.icns <<'PY'
import pathlib, struct, sys
folder = pathlib.Path(sys.argv[1])
types = {16:b'icp4', 32:b'icp5', 64:b'icp6', 128:b'ic07', 256:b'ic08', 512:b'ic09', 1024:b'ic10'}
chunks = []
for size, kind in types.items():
    data = (folder / f'{size}.png').read_bytes()
    chunks.append(kind + struct.pack('>I', len(data) + 8) + data)
body = b''.join(chunks)
pathlib.Path(sys.argv[2]).write_bytes(b'icns' + struct.pack('>I', len(body) + 8) + body)
PY
