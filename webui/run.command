#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec /bin/bash "$SCRIPT_DIR/raycast/open-hledger-web.sh" "$@"
