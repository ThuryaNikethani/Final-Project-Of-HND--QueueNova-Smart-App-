#!/usr/bin/env bash
set -euo pipefail

# Builds the Flutter web dashboard on Vercel's build machine, which has no
# Flutter SDK preinstalled. Pinned to the version this repo is developed
# against (see `flutter --version` locally) so cloud builds match local ones.
FLUTTER_VERSION="3.35.3"
FLUTTER_SDK_DIR="$HOME/flutter-sdk"

if [ ! -d "$FLUTTER_SDK_DIR" ]; then
  git clone --branch "$FLUTTER_VERSION" --depth 1 https://github.com/flutter/flutter.git "$FLUTTER_SDK_DIR"
fi
export PATH="$FLUTTER_SDK_DIR/bin:$PATH"

flutter config --enable-web --no-analytics
flutter pub get
flutter build web -t lib/web/web_main.dart --release --dart-define=API_ORIGIN="${API_ORIGIN:-http://localhost:3000}"
