#!/bin/sh

set -eu

if [ "${CONFIGURATION:-}" != "Release" ]; then
  exit 0
fi

case "${VIA_API_BASE_URL:-}" in
  ""|*.invalid/*|*.invalid)
    echo "error: VIA_API_BASE_URL must be a real HTTPS production URL before archiving Via."
    exit 1
    ;;
  https://*) ;;
  *)
    echo "error: VIA_API_BASE_URL must use HTTPS for Release."
    exit 1
    ;;
esac

