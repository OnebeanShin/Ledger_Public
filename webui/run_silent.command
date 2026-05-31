#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PORT="${PORT:-5001}"
RUN_SCRIPT="$SCRIPT_DIR/run.sh"
LOG="${TMPDIR:-/tmp}/hledger-web.log"

if lsof -i :"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
  echo "가계부 웹 서버가 이미 실행 중입니다: http://127.0.0.1:$PORT"
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
    echo "가계부 웹 서버를 시작했습니다: http://127.0.0.1:$PORT"
    echo "로그: $LOG"
    exit 0
  fi
done

echo "서버 시작 실패 — 원인: $LOG 를 확인하세요"
exit 1
