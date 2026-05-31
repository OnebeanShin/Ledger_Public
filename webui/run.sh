#!/bin/bash
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"

# LEDGER_FILE이 설정되지 않았으면 부모 디렉토리의 main.journal 사용
export LEDGER_FILE="${LEDGER_FILE:-$(cd "$DIR/.." && pwd)/main.journal}"
LEDGER_DIR="$(dirname "$LEDGER_FILE")"
export LEDGER_PRICES_FILE="${LEDGER_PRICES_FILE:-$LEDGER_DIR/prices.journal}"
export LEDGER_SCRIPTS_DIR="${LEDGER_SCRIPTS_DIR:-$LEDGER_DIR/scripts}"

"$LEDGER_SCRIPTS_DIR/update-prices.sh" 2>/dev/null || true

cd "$DIR"
export PORT="${PORT:-5001}"
TS_IP=$( { command -v tailscale >/dev/null 2>&1 && tailscale ip -4; } 2>/dev/null || echo "127.0.0.1")
if [ -z "$TS_IP" ]; then
    TS_IP="127.0.0.1"
fi
DEFAULT_IFACE=$(route get default 2>/dev/null | awk '/interface:/{print $2; exit}' || true)
LAN_IP=""
if [ -n "$DEFAULT_IFACE" ]; then
    LAN_IP=$(ipconfig getifaddr "$DEFAULT_IFACE" 2>/dev/null || true)
fi
export WEBUI_HOST="${WEBUI_HOST:-0.0.0.0}"
if [ -z "${WEBUI_ALLOWED_CLIENT_NETWORKS:-}" ]; then
    WEBUI_ALLOWED_CLIENT_NETWORKS="127.0.0.0/8,::1/128,100.64.0.0/10"
    if [ -n "$LAN_IP" ]; then
        WEBUI_ALLOWED_CLIENT_NETWORKS="$WEBUI_ALLOWED_CLIENT_NETWORKS,$LAN_IP/32"
    fi
    export WEBUI_ALLOWED_CLIENT_NETWORKS
fi
echo "Ledger file: $LEDGER_FILE"
echo "Starting hledger Dashboard at http://127.0.0.1:$PORT"
if [ -n "$LAN_IP" ]; then
    echo "Local machine URL: http://$LAN_IP:$PORT"
fi
if [ "$TS_IP" != "127.0.0.1" ]; then
    echo "Tailscale URL: http://$TS_IP:$PORT"
fi
exec python3 app.py
