#!/usr/bin/env bash
# Run Flutter against deployed Fly.io API (read-only demo mode)
#
# Usage: 
#   ./scripts/run_preview.sh
#   FLUTTER_DEVICE=edge ./scripts/run_preview.sh

set -euo pipefail

# Defaults (can be overridden via environment variables)
API_BASE_URL="${API_BASE_URL:-https://anderson-express-api.fly.dev}"
APP_ENV="${APP_ENV:-preview}"
DEMO_MODE="${DEMO_MODE:-true}"
DEBUG_BACKEND_OVERRIDE="${DEBUG_BACKEND_OVERRIDE:-false}"
FLUTTER_DEVICE="${FLUTTER_DEVICE:-chrome}"

echo "🎭 Starting Flutter in PREVIEW/DEMO mode..."
echo "   API: $API_BASE_URL"
echo "   Demo Mode: $DEMO_MODE"
echo "   Device: $FLUTTER_DEVICE"
echo ""

flutter run -d "$FLUTTER_DEVICE" \
  --dart-define=API_BASE_URL="$API_BASE_URL" \
  --dart-define=APP_ENV="$APP_ENV" \
  --dart-define=DEMO_MODE="$DEMO_MODE" \
  --dart-define=DEBUG_BACKEND_OVERRIDE="$DEBUG_BACKEND_OVERRIDE" \
  "$@"
