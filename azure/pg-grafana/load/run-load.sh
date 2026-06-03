#!/bin/sh
# Drive demo traffic: every LOAD_INTERVAL_SECONDS, run a small batch of queries
# against the managed Postgres "postgres" database so the dashboards have
# something to show.
set -u

: "${PGHOST:?PGHOST is required}"
: "${PGUSER:?PGUSER is required}"
: "${PGPASSWORD:?PGPASSWORD is required}"
PGDATABASE="${PGDATABASE:-postgres}"
PGSSLMODE="${PGSSLMODE:-require}"
INTERVAL="${LOAD_INTERVAL_SECONDS:-300}"

export PGPASSWORD PGSSLMODE

echo "[load] target=${PGHOST} db=${PGDATABASE} interval=${INTERVAL}s"

while true; do
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "[load] ${ts} running query batch"
  i=1
  while [ "$i" -le 20 ]; do
    psql -h "$PGHOST" -U "$PGUSER" -d "$PGDATABASE" -v ON_ERROR_STOP=0 -tAc \
      "SELECT count(*) FROM pg_stat_activity; SELECT now(); SELECT pg_database_size(current_database());" \
      >/dev/null 2>&1 || echo "[load] query ${i} failed"
    i=$((i + 1))
  done
  echo "[load] batch done; sleeping ${INTERVAL}s"
  sleep "$INTERVAL"
done
