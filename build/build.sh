#!/usr/bin/env bash
set -euo pipefail

# Local build script to produce platform binaries under build/dist
# Usage: ./build/build.sh [vX.Y.Z]

VERSION=${1:-local}
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/build/dist"
mkdir -p "$DIST_DIR"

PLATFORMS=("linux:amd64" "linux:arm64" "darwin:amd64" "darwin:arm64" "windows:amd64" "windows:arm64")
for platform in "${PLATFORMS[@]}"; do
  IFS=":" read -r GOOS GOARCH <<< "$platform"
  echo "Building for $GOOS/$GOARCH"
  OUT_DIR="$DIST_DIR/$GOOS-$GOARCH"
  mkdir -p "$OUT_DIR"
  EXT=""
  if [ "$GOOS" = "windows" ]; then
    EXT=".exe"
  fi
  BIN_NAME="cifs-exporter${EXT}"
  CGO_ENABLED=0 GOOS=$GOOS GOARCH=$GOARCH go build -ldflags "-X main.version=$VERSION" -o "$OUT_DIR/$BIN_NAME" .
  pushd "$OUT_DIR" > /dev/null
  if [ "$GOOS" = "windows" ]; then
    zip -r "cifs-exporter-${GOOS}-${GOARCH}.zip" "$BIN_NAME" >/dev/null
  else
    tar czf "cifs-exporter-${GOOS}-${GOARCH}.tar.gz" "$BIN_NAME"
  fi
  popd > /dev/null
done

echo "Build artifacts in: $DIST_DIR"

