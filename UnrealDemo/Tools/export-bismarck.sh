#!/bin/zsh
# Bismarck (Sources/Bismarck) for Unreal: OBJ, MTL, textures and hydrostatics in UnrealDemo/Import/Bismarck
# (or the folder given). The U-boat's export and the game sources are not involved.
set -euo pipefail
OUT="${1:-}"
cd "$(dirname "$0")/../.."
mkdir -p build/module-cache
xcrun swiftc -swift-version 5 -O -target arm64-apple-macosx13.0 -module-cache-path "$PWD/build/module-cache" \
    UnrealDemo/Tools/export-bismarck.swift Sources/Bismarck/*.swift -o build/export-bismarck \
    -framework AppKit -framework SceneKit -framework ModelIO -framework Metal
build/export-bismarck "${OUT:-$PWD/UnrealDemo/Import/Bismarck}"
