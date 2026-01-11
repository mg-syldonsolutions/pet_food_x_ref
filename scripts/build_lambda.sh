#!/usr/bin/env bash
set -euo pipefail

echo "▶ Building Lambda artifact (Python 3.14, arm64)"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/services/api/.build"
ZIP_OUT="$ROOT_DIR/infra/envs/prod/build/api.zip"

echo "• Cleaning build dir"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "• Installing dependencies in Lambda Linux"
docker run --rm \
  --platform linux/arm64 \
  --entrypoint /bin/bash \
  -v "$BUILD_DIR:/var/task" \
  public.ecr.aws/lambda/python:3.14 \
  -lc 'pip install -t /var/task "psycopg[binary]"'

echo "• Copying Lambda handler and app code"
cp "$ROOT_DIR/services/api/lambdas/api_handler.py" "$BUILD_DIR/"
mkdir -p "$BUILD_DIR/app"
cp -R "$ROOT_DIR/services/api/src/app/"* "$BUILD_DIR/app/"

if [ -d "$ROOT_DIR/services/api/db" ]; then
  echo "• Copying DB SQL files"
  mkdir -p "$BUILD_DIR/db"
  cp -R "$ROOT_DIR/services/api/db/"* "$BUILD_DIR/db/"
fi



echo "• Creating zip artifact"
mkdir -p "$(dirname "$ZIP_OUT")"
cd "$BUILD_DIR"
zip -r "$ZIP_OUT" .

echo "✓ Lambda build complete:"
ls -lh "$ZIP_OUT"

