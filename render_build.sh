#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

echo "Starting Flutter web build for Render..."

# 1. Download Flutter if it doesn't already exist in the build environment
if [ ! -d "flutter_sdk" ]; then
  echo "Cloning Flutter stable channel..."
  git clone https://github.com/flutter/flutter.git -b stable flutter_sdk
fi

# 2. Add Flutter to the path
export PATH="$PATH:`pwd`/flutter_sdk/bin"

# 3. Enable web support (just in case)
flutter config --enable-web

# 4. Get dependencies and build the web project
echo "Fetching dependencies..."
flutter pub get

echo "Building Flutter Web..."
flutter build web

echo "Build complete! Files are in build/web"
