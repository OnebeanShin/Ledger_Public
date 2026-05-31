#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Open 가계부 Web
# @raycast.mode silent
#
# Optional parameters:
# @raycast.packageName Ledger
# @raycast.icon 📊
# @raycast.description 가계부 웹 대시보드 서버 시작 + 브라우저 열기

# 기본 5001: macOS는 5000을 AirPlay가 점유해 스크립트가 잘못된 서비스로 열리거나 Flask가 뜨지 않을 수 있음
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WEBUI_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
RUN_SCRIPT="$WEBUI_DIR/run.sh"
PORT="${PORT:-5001}"
LOG="${TMPDIR:-/tmp}/hledger-web.log"

if lsof -i :"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
  open "http://127.0.0.1:$PORT"
  echo "이미 실행 중 — 브라우저에서 열었습니다"
  exit 0
fi

if [ ! -f "$RUN_SCRIPT" ]; then
  echo "run.sh 경로 없음: $RUN_SCRIPT" >&2
  exit 1
fi

export PORT
: >"$LOG"
nohup /bin/zsh "$RUN_SCRIPT" >>"$LOG" 2>&1 &

for i in $(seq 1 20); do
  sleep 0.25
  if lsof -i :"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
    open "http://127.0.0.1:$PORT"
    echo "가계부 웹 대시보드를 열었습니다"
    exit 0
  fi
done

echo "서버 시작 실패 — 원인: $LOG 를 확인하세요"
exit 1
