#!/bin/zsh
set -euo pipefail
OUT="${1:-}"
cd "$(dirname "$0")/../.."
set -- ${OUT:+"$OUT"}
mkdir -p build/module-cache
# Only the exporter uses an unbatched assembly. Game sources remain unchanged.
python3 - <<'PY'
from pathlib import Path
p=Path('Sources/DetailedModel.swift').read_text()
assert 'let merged=batchStaticHierarchy(fixed)' in p
Path('build/DetailedModelExport.swift').write_text(p.replace('let merged=batchStaticHierarchy(fixed)','let merged=fixed'))
PY
xcrun swiftc -swift-version 5 -O -target arm64-apple-macosx13.0 -module-cache-path "$PWD/build/module-cache" UnrealDemo/Tools/export-submarine.swift Sources/Model*.swift Sources/DetailedDeck.swift Sources/DetailedParts.swift Sources/DetailedHull.swift Sources/DetailedTower.swift Sources/DetailedGear.swift build/DetailedModelExport.swift Sources/Simulation.swift -o build/export-submarine -framework AppKit -framework SceneKit -framework ModelIO -framework Metal
# Optional first argument: output folder (default UnrealDemo/Import).
build/export-submarine "${1:-$PWD/UnrealDemo/Import}"
