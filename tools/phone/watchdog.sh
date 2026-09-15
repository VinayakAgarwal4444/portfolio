#!/data/data/com.termux/files/usr/bin/sh
LOG=$HOME/watchdog.log
PIDFILE=$HOME/tunnel.pid

alive=0
if [ -f "$PIDFILE" ]; then
  if kill -0 "$(cat $PIDFILE)" 2>/dev/null; then
    alive=1
  fi
fi

if [ "$alive" -eq 0 ]; then
  echo "$(date '+%F %T') restarting tunnel" >> $LOG
  nohup cloudflared tunnel run phone-site >> $HOME/tunnel.log 2>&1 &
  echo $! > "$PIDFILE"
fi

if ! pgrep nginx > /dev/null 2>&1; then
  echo "$(date '+%F %T') restarting nginx" >> $LOG
  nginx
fi

if ! pgrep sshd > /dev/null 2>&1; then
  echo "$(date '+%F %T') restarting sshd" >> $LOG
  sshd
fi
