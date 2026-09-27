#!/usr/bin/env bash
# Watchdog sederhana: cek 9Router dan Hermes Telegram gateway, restart yang mati.
# Dijalankan via cron tiap 5 menit, contoh:
#   */5 * * * * /home/USER/hermes-9router-tutorial/scripts/watchdog.sh >> /home/USER/.hermes/watchdog.log 2>&1
#
# Sesuaikan variabel di bawah dengan setup-mu. TIDAK ada kredensial di sini.
set -uo pipefail

# ---------------- Konfigurasi (ubah sesuai setup) ----------------
NINE_ROUTER_PORT="${NINE_ROUTER_PORT:-20128}"
NINE_ROUTER_HOST="${NINE_ROUTER_HOST:-127.0.0.1}"
NINE_ROUTER_BIN="${NINE_ROUTER_BIN:-9router}"          # hasil: npm install -g 9router
HERMES_BIN="${HERMES_BIN:-hermes}"                     # perintah hermes di PATH
HERMES_HOME_DIR="${HERMES_HOME:-$HOME/.hermes}"
LOG_FILE="${WATCHDOG_LOG:-$HERMES_HOME_DIR/watchdog.log}"
# -----------------------------------------------------------------

ts() { date -u '+%Y-%m-%d %H:%M:%S UTC'; }

log() {
  local msg="[$(ts)] $*"
  echo "$msg"
  mkdir -p "$(dirname "$LOG_FILE")"
  echo "$msg" >> "$LOG_FILE"
}

restarted=""

# --- 1. 9Router: cek port merespons ---
if curl -sf --max-time 5 "http://${NINE_ROUTER_HOST}:${NINE_ROUTER_PORT}/" >/dev/null 2>&1; then
  : # sehat
else
  log "9router mati/tidak merespons di ${NINE_ROUTER_HOST}:${NINE_ROUTER_PORT} — restart..."
  pkill -f "9router -p" 2>/dev/null || true
  sleep 2
  # shellcheck disable=SC2086
  setsid nohup $NINE_ROUTER_BIN -p "$NINE_ROUTER_PORT" -H "$NINE_ROUTER_HOST" -n --skip-update \
    >> "$HERMES_HOME_DIR/9router.log" 2>&1 < /dev/null &
  restarted="${restarted} 9router"
fi

# --- 2. Telegram gateway: cek proses hermes gateway ---
if pgrep -f "hermes gateway" >/dev/null 2>&1; then
  : # sehat
else
  log "Telegram gateway mati — restart..."
  # shellcheck disable=SC2086
  setsid nohup env HERMES_HOME="$HERMES_HOME_DIR" $HERMES_BIN gateway run \
    >> "$HERMES_HOME_DIR/gateway.log" 2>&1 < /dev/null &
  restarted="${restarted} gateway"
fi

# --- 3. Ringkasan ---
if [ -n "$restarted" ]; then
  log "watchdog restarted:${restarted}"
else
  # Sehat: tidak perlu berisik. Cukup tandai di log sesekali? Tidak — diam saja.
  :
fi
