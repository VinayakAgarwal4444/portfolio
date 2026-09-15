import sqlite3, os, hashlib
from datetime import datetime

HOME = os.environ["HOME"]
LOG = f"{HOME}/../usr/var/log/nginx/edge.log"
db = sqlite3.connect(f"{HOME}/telemetry.db")

db.execute("""CREATE TABLE IF NOT EXISTS requests (
  ts INTEGER, ip_hash TEXT, country TEXT, method TEXT, path TEXT,
  status INTEGER, bytes INTEGER, resp_time REAL, ua TEXT, referer TEXT,
  UNIQUE(ts, ip_hash, path))""")

SALT = "change-this-to-anything"

def anon(ip):
    return hashlib.sha256((SALT + (ip or "")).encode()).hexdigest()[:12]

n = 0
for line in open(LOG, errors="replace"):
    p = line.rstrip("\n").split("|")
    if len(p) < 10:
        continue
    try:
        ts = int(datetime.fromisoformat(p[0]).timestamp())
    except ValueError:
        continue
    try:
        db.execute("INSERT OR IGNORE INTO requests VALUES (?,?,?,?,?,?,?,?,?,?)",
            (ts, anon(p[1]), p[2], p[3], p[4], int(p[5] or 0),
             int(p[6] or 0), float(p[7] or 0), p[8][:200], p[9][:200]))
        n += 1
    except (ValueError, sqlite3.Error):
        continue

db.commit()
print(f"processed {n} lines")
