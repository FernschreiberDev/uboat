#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")"
ENGINE='/Users/Shared/Epic Games/UE_5.8/Engine/Binaries/Mac/UnrealEditor.app/Contents/MacOS/UnrealEditor'
if [[ ! -x "$ENGINE" ]]; then
  print 'Unreal 5.8 est introuvable dans /Users/Shared/Epic Games.'
  read '?Appuyez sur Entrée pour fermer.'
  exit 1
fi
if ! xcrun metal --version >/dev/null 2>&1; then
  xcrun --kill-cache
fi
exec "$ENGINE" "$PWD/NordatlantikDemo.uproject" /Game/Demo/AtlanticCoast -game -windowed -ResX=1600 -ResY=900 -NoSplash
