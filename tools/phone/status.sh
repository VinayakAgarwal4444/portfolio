#!/data/data/com.termux/files/usr/bin/sh
# Writes live device telemetry to the web root as status.json.
# Run on a loop from the Termux:Boot script.
#
# Android 12+ denies unprivileged reads of /proc/uptime and /proc/loadavg,
# so service uptime is tracked with a marker file written at boot instead.
mkdir -p $HOME/portfolio-data
WWW="$HOME/www"
OUT="$HOME/portfolio-data/status.json"
TMP="$WWW/.status.json.tmp"
LOG="$PREFIX/var/log/nginx/access.log"
MARK="$HOME/.server-start"

BAT=$(termux-battery-status 2>/dev/null)
case "$BAT" in
  \{*) ;;
  *) BAT='{}' ;;
esac

# Service uptime. The marker is written once per boot; if it is missing
# we are starting now, so create it.
[ -f "$MARK" ] || date +%s > "$MARK"
STARTED=$(cat "$MARK")
NOW=$(date +%s)
UP=$((NOW - STARTED))
[ "$UP" -lt 0 ] && UP=0

MEM_TOTAL=$(awk '/^MemTotal:/{print $2}' /proc/meminfo)
MEM_FREE=$(awk '/^MemAvailable:/{print $2}' /proc/meminfo)
[ -z "$MEM_TOTAL" ] && MEM_TOTAL=0
[ -z "$MEM_FREE" ] && MEM_FREE=0

TODAY=$(date +%d/%b/%Y)
if [ -r "$LOG" ]; then
  HITS=$(grep -c "$TODAY" "$LOG")
else
  HITS=0
fi
[ -z "$HITS" ] && HITS=0

cat > "$TMP" <<EOF
{
  "updated": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "uptime_seconds": $UP,
  "mem_total_kb": $MEM_TOTAL,
  "mem_available_kb": $MEM_FREE,
  "requests_today": $HITS,
  "battery": $BAT
}
EOF

# Atomic swap so nginx never serves a half-written file.
mv "$TMP" "$OUT"
