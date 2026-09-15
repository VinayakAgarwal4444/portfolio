import sqlite3, json, os, time

HOME = os.environ["HOME"]
DB = f"{HOME}/telemetry.db"
OUT = f"{HOME}/portfolio-data/telemetry.json"

db = sqlite3.connect(DB)
db.row_factory = sqlite3.Row

samples = db.execute("""
  SELECT ts, battery_pct, battery_temp, plugged, rssi,
         resp_secs, nginx_up, tunnel_up, latency_ms
  FROM samples
  WHERE ts > strftime('%s','now','-30 days')
  ORDER BY ts
""").fetchall()

hourly = db.execute("""
  SELECT strftime('%Y-%m-%dT%H:00', ts, 'unixepoch') hour,
         COUNT(*) reqs,
         COUNT(DISTINCT ip_hash) visitors
  FROM requests
  WHERE country != '-' AND path NOT LIKE '/status%'
    AND ts > strftime('%s','now','-30 days')
  GROUP BY hour ORDER BY hour
""").fetchall()

paths = db.execute("""
  SELECT path, COUNT(*) n FROM requests
  WHERE country != '-' AND path NOT LIKE '/status%'
  GROUP BY path ORDER BY n DESC LIMIT 20
""").fetchall()

countries = db.execute("""
  SELECT country, COUNT(*) n FROM requests
  WHERE country NOT IN ('-','')
  GROUP BY country ORDER BY n DESC
""").fetchall()

suspicious = db.execute("""
  SELECT COUNT(*) n FROM requests
  WHERE status = 404
     OR ua LIKE '%python-requests%' OR ua LIKE '%curl/%'
     OR ua LIKE '%Go-http%' OR ua = ''
""").fetchone()["n"]

summary = db.execute("""
  SELECT COUNT(*) n, MIN(ts) first_ts, MAX(ts) last_ts,
         ROUND(AVG(battery_temp),1) temp_avg,
         ROUND(MAX(battery_temp),1) temp_max,
         ROUND(AVG(latency_ms),1) lat_avg,
         ROUND(AVG(resp_secs)*1000,2) resp_avg_ms,
         SUM(CASE WHEN nginx_up=0 OR tunnel_up=0 THEN 1 ELSE 0 END) degraded
  FROM samples
""").fetchone()

out = {
  "generated": int(time.time()),
  "summary": dict(summary),
  "suspicious_requests": suspicious,
  "samples": [dict(r) for r in samples],
  "hourly": [dict(r) for r in hourly],
  "paths": [dict(r) for r in paths],
  "countries": [dict(r) for r in countries],
}

os.makedirs(os.path.dirname(OUT), exist_ok=True)
with open(OUT, "w") as f:
    json.dump(out, f, separators=(",", ":"))

print(f"{len(samples)} samples, {len(hourly)} hours, {suspicious} suspicious")
