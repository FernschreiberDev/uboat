#!/bin/zsh
# Put the exported Bismarck (Tools/export-bismarck.sh) at sea in /Game/Bismarck/AtlanticBismarck with
# Content/Python/port_bismarck.py (or the script given, with its arguments: port-bismarck.sh livery_bismarck.py 21mai),
# in the full editor, which quits by itself. The log goes to
# Saved/Logs/Bismarck-<script>.log. Refuses to start while an Unreal editor is running.
set -euo pipefail
cd "$(dirname "$0")/.."
ENGINE='/Users/Shared/Epic Games/UE_5.8/Engine/Binaries/Mac/UnrealEditor.app/Contents/MacOS/UnrealEditor'
SCRIPT="${1:-port_bismarck.py}"
ARGS="${*:2}"   # e.g. 21mai or 24mai for the livery
if ps -axo command | grep -E "MacOS/UnrealEditor(-Cmd)? " | grep -v grep >/dev/null; then
  print "Un éditeur Unreal est déjà ouvert : fermez-le d'abord."
  exit 1
fi
mkdir -p Saved/Logs
LOG="$PWD/Saved/Logs/Bismarck-${SCRIPT%.py}.log"
# The editor opens the Bismarck's level. The first port only saves it as a copy of AtlanticDemo (left
# unchanged), then runs again on the copy.
for pass in 1 2; do
  MAP=/Game/Bismarck/AtlanticBismarck
  [[ -f Content/Bismarck/AtlanticBismarck.umap ]] || MAP=/Game/Demo/AtlanticDemo
  "$ENGINE" "$PWD/NordatlantikDemo.uproject" "$MAP" -ExecCmds="py $PWD/Content/Python/$SCRIPT $ARGS" \
      -NoSplash -abslog="$LOG" || true
  grep -q "BISMARCK_PORT: COPY_SAVED" "$LOG" || break
done
grep -E "BISMARCK_|Error|FAILED" "$LOG" | grep -v "LogPython: Error: $" | head -80
