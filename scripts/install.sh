#!/usr/bin/env bash
# Install otomatis: Hermes Agent + Node.js + 9Router di VM Linux (Debian/Ubuntu).
# Dijalankan sebagai user biasa (bukan root). Tidak butuh input interaktif
# kecuali saat login provider nanti (langkah manual setelah script selesai).
#
# Cara pakai:
#   bash scripts/install.sh
set -euo pipefail

log() { printf '\033[1;32m[install]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[install]\033[0m %s\n' "$*" >&2; }

# --- 1. Cek OS ---
if ! command -v apt-get >/dev/null 2>&1; then
  warn "Script ini untuk Debian/Ubuntu (butuh apt-get). Install manual untuk distro lain."
  exit 1
fi

# --- 2. Dependensi dasar ---
log "Menginstall dependensi dasar (git, curl, tar)..."
sudo apt-get update -y
sudo apt-get install -y git curl tar ca-certificates

# --- 3. Node.js LTS (dibutuhkan 9Router via npm) ---
if ! command -v node >/dev/null 2>&1; then
  log "Menginstall Node.js LTS via NodeSource..."
  curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
  sudo apt-get install -y nodejs
else
  log "Node.js sudah ada: $(node --version)"
fi

# --- 4. Hermes Agent (installer resmi Nous Research) ---
if ! command -v hermes >/dev/null 2>&1; then
  log "Menginstall Hermes Agent..."
  curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash -s -- --skip-browser
  # shellcheck disable=SC1090
  source ~/.bashrc 2>/dev/null || true
  export PATH="$HOME/.local/bin:$PATH"
else
  log "Hermes sudah ada: $(hermes --version 2>/dev/null || echo '?')"
fi

# --- 5. 9Router (paket npm) ---
if ! command -v 9router >/dev/null 2>&1; then
  log "Menginstall 9Router..."
  npm install -g 9router
else
  log "9Router sudah ada: $(9router --version 2>/dev/null || echo '?')"
fi

# --- 6. Verifikasi ---
log "Verifikasi instalasi Hermes..."
export PATH="$HOME/.local/bin:$PATH"
if hermes doctor; then
  log "hermes doctor: OK"
else
  warn "hermes doctor menemukan masalah — lihat output di atas."
fi

cat << 'EOF'

============================================================
 Instalasi selesai. Langkah manual berikutnya:
  1. hermes setup --portal     # login provider model (OAuth)
     atau: hermes model        # pilih provider/model
  2. Buat bot Telegram via @BotFather, catat tokennya.
  3. Dapatkan numeric ID via @userinfobot.
  4. hermes gateway setup       # isi token bot + allowlist ID
  5. 9router -p 20128 -H 127.0.0.1 -n --skip-update
  6. hermes gateway run         # verifikasi "Connected to Telegram"
 Lihat README.md untuk detail tiap langkah.
============================================================
EOF
