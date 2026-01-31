#!/usr/bin/env bash
set -euo pipefail

REGION="${AWS_DEFAULT_REGION:-us-east-1}"
ENDPOINT="${ENDPOINT_URL:-http://localhost:4566}"

# Helpers
inv_urgency () {
  python - <<'PY'
u=int(__import__("os").environ["U"])
print(f"{9999-u:04d}")
PY
}

put_access () {
  local user="$1" study="$2" role="$3"
  aws dynamodb put-item \
    --table-name Access \
    --endpoint-url "$ENDPOINT" \
    --region "$REGION" \
    --item "{
      \"pk\": {\"S\": \"U#${user}\"},
      \"sk\": {\"S\": \"S#${study}#R#${role}\"}
    }" >/dev/null
}

put_item_and_index () {
  local item_id="$1" type="$2" study="$3" urgency="$4" day="$5" bucket="$6"

  local updated_at
  updated_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  # Items (fonte)
  aws dynamodb put-item \
    --table-name Items \
    --endpoint-url "$ENDPOINT" \
    --region "$REGION" \
    --item "{
      \"pk\": {\"S\": \"ITEM#${item_id}\"},
      \"sk\": {\"S\": \"META#${type}\"},
      \"item_id\": {\"S\": \"${item_id}\"},
      \"type\": {\"S\": \"${type}\"},
      \"study_id\": {\"S\": \"${study}\"},
      \"urgency\": {\"N\": \"${urgency}\"},
      \"updated_at\": {\"S\": \"${updated_at}\"},
      \"status\": {\"S\": \"OPEN\"},
      \"title\": {\"S\": \"${type} - ${item_id}\"}
    }" >/dev/null

  # UrgencyIndex (view para ordenar)
  export U="${urgency}"
  local inv
  inv="$(inv_urgency)"

  aws dynamodb put-item \
    --table-name UrgencyIndex \
    --endpoint-url "$ENDPOINT" \
    --region "$REGION" \
    --item "{
      \"pk\": {\"S\": \"S#${study}#T#${type}#D#${day}#B#${bucket}\"},
      \"sk\": {\"S\": \"U#${inv}#TS#${updated_at}#I#${item_id}\"},
      \"study_id\": {\"S\": \"${study}\"},
      \"type\": {\"S\": \"${type}\"},
      \"day\": {\"S\": \"${day}\"},
      \"bucket\": {\"N\": \"${bucket}\"},
      \"urgency\": {\"N\": \"${urgency}\"},
      \"item_id\": {\"S\": \"${item_id}\"}
    }" >/dev/null
}

echo "Seeding RBAC..."
put_access "u1" "studyA" "REVIEWER"
put_access "u1" "studyB" "REVIEWER"
put_access "u2" "studyB" "REVIEWER"   # u2 não tem studyA

DAY="$(date -u +"%Y%m%d")"

echo "Seeding items + index (DAY=$DAY)..."
# 2 tipos, 2 studies, buckets 0..3 (simples)
for i in $(seq 1 10); do
  put_item_and_index "A-Q${i}" "DataQuery" "studyA" $((RANDOM % 100)) "$DAY" $((i % 4))
  put_item_and_index "A-S${i}" "SafetyEvent" "studyA" $((RANDOM % 100)) "$DAY" $(((i+1) % 4))
done

for i in $(seq 1 10); do
  put_item_and_index "B-Q${i}" "DataQuery" "studyB" $((RANDOM % 100)) "$DAY" $((i % 4))
  put_item_and_index "B-S${i}" "SafetyEvent" "studyB" $((RANDOM % 100)) "$DAY" $(((i+1) % 4))
done

echo "Done."
