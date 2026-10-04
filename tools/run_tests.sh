#!/usr/bin/env bash
# Roda todos os testes GUT em modo headless. Sai com código != 0 se algum falhar.
# Uso: tools/run_tests.sh [argumentos extras do GUT, ex: -gselect=test_sp_pool.gd]
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
# Importa recursos e registra class_name (necessário na primeira execução / clone limpo).
"$GODOT" --headless --import >/dev/null 2>&1 || true
"$GODOT" --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json "$@"
