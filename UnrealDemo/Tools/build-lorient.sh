#!/bin/zsh
# Build /Game/Lorient/LorientKeroman from AtlanticVoyage and the files of Import/Lorient, in the full
# editor (twice: copy, then populate), which quits by itself after each pass. Logs go to
# Saved/Logs/Lorient-*.log. Refuses to start while an Unreal editor is running.
# Compile the C++ module first (see README): the map uses the Voyage game mode.
set -euo pipefail
cd "$(dirname "$0")/.."
ENGINE='/Users/Shared/Epic Games/UE_5.8/Engine/Binaries/Mac/UnrealEditor.app/Contents/MacOS/UnrealEditor'
if ps -axo command | grep -E "MacOS/UnrealEditor(-Cmd)? " | grep -v grep >/dev/null; then
  print "Un éditeur Unreal est déjà ouvert : fermez-le d'abord."
  exit 1
fi
mkdir -p Saved/Logs
if [[ ! -f Content/Lorient/LorientKeroman.umap ]]; then
  "$ENGINE" "$PWD/NordatlantikDemo.uproject" /Game/Voyage/AtlanticVoyage \
      -ExecCmds="py $PWD/Content/Python/build_lorient.py" -NoSplash -abslog="$PWD/Saved/Logs/Lorient-copy.log" || true
  grep -q "LORIENT_COPY_READY" Saved/Logs/Lorient-copy.log || { grep -E "Error|LORIENT" Saved/Logs/Lorient-copy.log | head -40; exit 1; }
fi
"$ENGINE" "$PWD/NordatlantikDemo.uproject" /Game/Lorient/LorientKeroman \
    -ExecCmds="py $PWD/Content/Python/populate_lorient.py" -NoSplash -abslog="$PWD/Saved/Logs/Lorient-populate.log" || true
grep -E "LORIENT|Error|FAILED" Saved/Logs/Lorient-populate.log | grep -v "LogPython: Error: $" | head -80
grep -q "LORIENT_MAP_BUILT" Saved/Logs/Lorient-populate.log
