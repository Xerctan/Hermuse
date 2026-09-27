#!/bin/bash
# Menjalankan Hermes CLI dari instalasi provisioned (venv) — replika dari VM Muse.
#
# Sesuaikan variabel di bawah dengan hasil instalasi Hermes di mesinmu:
#   HERMES_VENV  -> venv hasil instalasi (cari di ~/.hermes/installs/*/.../venv)
#   HERMES_SRC   -> checkout source hermes-agent (dipakai bila menjalankan via
#                   venv + source seperti di sini)
#   HERMES_HOME  -> home Hermes (default ~/.hermes)
#
# Kalau Hermes-mu terinstall normal (perintah `hermes` sudah ada di PATH),
# kamu tidak butuh script ini — pakai `hermes` langsung.

VENV="${HERMES_VENV:-$HOME/.hermes/installs/<INSTALL_ID>/environments/<ENV_ID>/venv}"
HERMES_SRC="${HERMES_SRC:-$HOME/hermes-agent}"
export HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"

# Daftar no_proxy minimal. (Catatan dari VM asal: entri IPv6 bracket seperti
# [::1] di no_proxy membuat httpx crash dengan "Invalid port" — pakai daftar
# minimal yang aman ini.)
export no_proxy="localhost,127.0.0.1"
export NO_PROXY="localhost,127.0.0.1"

exec "$VENV/bin/python" -c "
import os, sys
sys.path.insert(0, os.environ['HERMES_SRC'])
from hermes_cli.main import main
sys.argv = ['hermes'] + sys.argv[1:]
main()
" "$@"
