#!/data/data/com.termux/files/usr/bin/sh
DB=$HOME/telemetry.db

sqlite3 "$DB" "CREATE TABLE IF NOT EXISTS samples (
  ts INTEGER PRIMARY KEY,
  battery_pct INTEGER, battery_temp REAL, plugged TEXT,
  rssi INTEGER, link_speed INTEGER,
  resp_secs REAL, disk_free_kb INTEGER,
  nginx_up INTEGER, tunnel_up INTEGER,
  latency_ms REAL
);"

BAT=$(termux-battery-status 2>/dev/null)
WIFI=$(termux-wifi-connectioninfo 2>/dev/null)

PCT=$(echo "$BAT"  | jq -r '.percentage // ""')
TEMP=$(echo "$BAT" | jq -r '.temperature // ""')
PLUG=$(echo "$BAT" | jq -r '.plugged // ""')
RSSI=$(echo "$WIFI" | jq -r '.rssi // ""')
SPEED=$(echo "$WIFI" | jq -r '.link_speed_mbps // ""')

LOAD=$(curl -o /dev/null -s -w '%{time_total}' --max-time 5 http://localhost:8080/)
MEM=$(df -k $HOME | awk 'NR==2 {print $4}')

pgrep nginx > /dev/null && NG=1 || NG=0
if [ -f "$HOME/tunnel.pid" ] && kill -0 "$(cat $HOME/tunnel.pid)" 2>/dev/null; then TU=1; else TU=0; fi

LAT=$(ping -c 1 -W 2 1.1.1.1 2>/dev/null | sed -n 's/.*time=\([0-9.]*\).*/\1/p')

sqlite3 "$DB" "INSERT OR REPLACE INTO samples VALUES (
  $(date +%s), ${PCT:-NULL}, ${TEMP:-NULL}, '${PLUG}',
  ${RSSI:-NULL}, ${SPEED:-NULL}, ${LOAD:-NULL}, ${MEM:-NULL},
  $NG, $TU, ${LAT:-NULL});"
