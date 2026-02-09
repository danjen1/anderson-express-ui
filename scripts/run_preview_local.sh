#!/usr/bin/env bash
# Run Flutter against LOCAL Rust API in demo mode (for testing demo behavior locally)
#
# Usage: 
#   ./scripts/run_preview_local.sh
#   FLUTTER_DEVICE=edge ./scripts/run_preview_local.sh

set -euo pipefail

# Defaults (can be overridden via environment variables)
API_BASE_URL="${API_BASE_URL:-http://localhost:9000}"
APP_ENV="${APP_ENV:-preview}"
DEMO_MODE="${DEMO_MODE:-true}"
DEBUG_BACKEND_OVERRIDE="${DEBUG_BACKEND_OVERRIDE:-false}"
FLUTTER_DEVICE="${FLUTTER_DEVICE:-chrome}"

echo "🎭 Starting Flutter in PREVIEW LOCAL mode..."
echo "   API: $API_BASE_URL (local backend)"
echo "   Demo Mode: $DEMO_MODE (read-only)"
echo "   Device: $FLUTTER_DEVICE"
echo ""

flutter run -d "$FLUTTER_DEVICE" \
  --dart-define=API_BASE_URL="$API_BASE_URL" \
  --dart-define=APP_ENV="$APP_ENV" \
  --dart-define=DEMO_MODE="$DEMO_MODE" \
  --dart-define=DEBUG_BACKEND_OVERRIDE="$DEBUG_BACKEND_OVERRIDE" \
  "$@"
