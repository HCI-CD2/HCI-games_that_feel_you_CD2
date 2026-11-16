#!/usr/bin/env bash
# Builds the browser version of the game into build/web, including the webcam tracker.
#
#   tools/build_web.sh            debug build (shows the face readout in the corner)
#   tools/build_web.sh release    release build (no readout)
#
# Uses "godot" from your PATH, or the Godot app in ~/Downloads on a Mac.
# To use another copy: GODOT=/path/to/godot tools/build_web.sh
set -euo pipefail

cd "$(dirname "$0")/.."

GODOT="${GODOT:-godot}"
if ! command -v "$GODOT" >/dev/null 2>&1 && [ -x "$HOME/Downloads/Godot.app/Contents/MacOS/Godot" ]; then
  GODOT="$HOME/Downloads/Godot.app/Contents/MacOS/Godot"
fi

MODE="${1:-debug}"
if [ "$MODE" != "debug" ] && [ "$MODE" != "release" ]; then
  echo "Usage: tools/build_web.sh [debug|release]" >&2
  exit 1
fi

mkdir -p build/web
"$GODOT" --headless --path . "--export-$MODE" "Web" build/web/index.html

# Godot only exports the game itself, so copy the tracker next to it.
rm -rf build/web/webcam
mkdir -p build/web/webcam
cp -R webcam/emotion.js webcam/face_tracker.js webcam/game_bridge.js \
      webcam/vendor webcam/models build/web/webcam/

echo "Built build/web ($MODE). Run: cd build/web && python3 -m http.server 8000"
