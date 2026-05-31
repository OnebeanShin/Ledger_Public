#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_FILE="$ROOT_DIR/prices.journal"
MAIN_FILE="${LEDGER_FILE:-$ROOT_DIR/main.journal}"

resolve_pricehist_bin() {
  local line
  local worktree_path
  local candidate
  local -a candidates=()
  typeset -A seen_paths

  append_candidate() {
    local path="$1"
    [[ -z "$path" ]] && return
    [[ -n "${seen_paths[$path]:-}" ]] && return
    seen_paths[$path]=1
    candidates+=("$path")
  }

  append_candidate "${PRICEHIST_BIN:-}"
  append_candidate "$ROOT_DIR/.venv-pricehist/bin/pricehist"

  if git -C "$ROOT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    while IFS= read -r line; do
      [[ "$line" == worktree\ * ]] || continue
      worktree_path="${line#worktree }"
      append_candidate "$worktree_path/.venv-pricehist/bin/pricehist"
    done < <(git -C "$ROOT_DIR" worktree list --porcelain 2>/dev/null)
  fi

  if command -v pricehist >/dev/null 2>&1; then
    append_candidate "$(command -v pricehist)"
  fi

  for candidate in "${candidates[@]}"; do
    if [[ -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  {
    echo "pricehist executable was not found."
    echo "Checked:"
    for candidate in "${candidates[@]}"; do
      echo "  - $candidate"
    done
    echo "Set PRICEHIST_BIN to override the path if needed."
  } >&2

  return 1
}

PRICEHIST_BIN="$(resolve_pricehist_bin)"

start_date="$(date -v-7d '+%Y-%m-%d')"
end_date="$(date '+%Y-%m-%d')"

tmp_prices="$(mktemp)"
tmp_existing="$(mktemp)"
trap 'rm -f "$tmp_prices" "$tmp_existing"' EXIT

detect_investment_symbols() {
  python3 - "$MAIN_FILE" <<'PY'
import json
import subprocess
import sys

main_file = sys.argv[1]
try:
    raw = subprocess.check_output(
        ["hledger", "-f", main_file, "print", "assets:investment", "-O", "json"],
        text=True,
        stderr=subprocess.PIPE,
    )
except subprocess.CalledProcessError as exc:
    sys.stderr.write(exc.stderr or str(exc))
    raise SystemExit(exc.returncode)

symbols = set()
for transaction in json.loads(raw):
    for posting in transaction.get("tpostings", []):
        account = posting.get("paccount", "")
        if not account.startswith("assets:investment"):
            continue
        for amount in posting.get("pamount", []):
            commodity = amount.get("acommodity")
            if commodity and commodity not in {"KRW", "USD"}:
                symbols.add(commodity)

for symbol in sorted(symbols, key=lambda s: (s != "BTC", s)):
    print(symbol)
PY
}

fetch_latest() {
  local symbol="$1"
  shift
  local line
  line="$("$PRICEHIST_BIN" fetch yahoo "$symbol" -t close -s "$start_date" -e "$end_date" -o ledger "$@" 2>/dev/null | tail -n 1)"
  if [[ -z "$line" ]]; then
    echo "No price data returned for symbol: $symbol" >&2
    exit 1
  fi
  printf '%s\n' "$line" >> "$tmp_prices"
}

fetch_investment_symbol() {
  local symbol="$1"
  case "$symbol" in
    BTC)
      fetch_latest "BTC-USD" --fmt-base BTC --fmt-quote USD
      ;;
    *)
      fetch_latest "$symbol"
      ;;
  esac
}

investment_symbols=("${(@f)$(detect_investment_symbols)}")
if (( ${#investment_symbols[@]} == 0 )); then
  echo "No investment commodities found in $MAIN_FILE" >&2
else
  echo "Updating prices for investment commodities: ${investment_symbols[*]}"
fi

for symbol in "${investment_symbols[@]}"; do
  fetch_investment_symbol "$symbol"
done
fetch_latest "KRW=X" --fmt-base USD --fmt-quote KRW

if [[ -f "$OUTPUT_FILE" ]]; then
  grep '^P ' "$OUTPUT_FILE" > "$tmp_existing" || true
fi

{
  echo "; Auto-generated market prices."
  echo "; Updated by scripts/update-prices.sh"
  echo
  cat "$tmp_existing" "$tmp_prices" 2>/dev/null \
    | awk '
        NF && $1 == "P" {
          key = $2 FS $3 FS $4 FS $6
          latest[key] = $0
        }
        END {
          for (key in latest) {
            print latest[key]
          }
        }
      ' \
    | LC_ALL=C sort
} > "$OUTPUT_FILE"

echo "Updated prices.journal with latest available market prices."
