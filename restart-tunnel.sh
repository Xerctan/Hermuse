#!/bin/bash
# Restart tunnel client detached.
# (Pola grep pakai bracket "[t]unnel-client" agar tidak bunuh diri sendiri.)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
P=$(ps aux | grep "[t]unnel-client" | awk '{print $2}')
if [ -n "$P" ]; then kill $P; sleep 2; fi
setsid nohup bash "$SCRIPT_DIR/start-pages-tunnel.sh" \
  > "$SCRIPT_DIR/pages-tunnel.log" 2>&1 < /dev/null &
echo "tunnel supervisor restarted"
