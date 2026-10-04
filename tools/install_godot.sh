#!/usr/bin/env bash
# Instala o Godot (Linux x86_64) usado pelo projeto e cria o comando `godot`.
# Uso: tools/install_godot.sh [versao]   (padrão: 4.7.2)
set -euo pipefail
VERSION="${1:-4.7.2}"
DEST="${GODOT_HOME:-/opt/godot}"
BIN="$DEST/Godot_v${VERSION}-stable_linux.x86_64"
if [[ ! -x "$BIN" ]]; then
	mkdir -p "$DEST"
	curl -fsSL -o "$DEST/godot.zip" \
		"https://github.com/godotengine/godot/releases/download/${VERSION}-stable/Godot_v${VERSION}-stable_linux.x86_64.zip"
	unzip -o -q "$DEST/godot.zip" -d "$DEST"
	rm -f "$DEST/godot.zip"
	chmod +x "$BIN"
fi
ln -sf "$BIN" /usr/local/bin/godot 2>/dev/null || echo "Adicione $BIN ao PATH como 'godot'."
godot --version
