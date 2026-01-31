#!/usr/bin/env bash
set -euo pipefail

REGION="${AWS_DEFAULT_REGION:-us-east-1}"
ENDPOINT="${ENDPOINT_URL:-http://localhost:4566}"
DAY="$(date -u +"%Y%m%d")"

put_item () {
  aws dynamodb put-item \
    --table-name "$1" \
    --endpoint-url "$ENDPOINT" \
    --region "$REGION" \
    --item "$2" >/dev/null
}

echo "Seeding RBAC (Access)..."
put_item "Access" "{\"pk\":{\"S\":\"U#u1\"},\"sk\":{\"S\":\"S#studyA#R#REVIEWER\"}}"
put_item "Access" "{\"pk\":{\"S\":\"U#u1\"},\"sk\":{\"S\":\"S#studyB#R#REVIEWER\"}}"
put_item "Access" "{\"pk\":{\"S\":\"U#u2\"},\"sk\":{\"S\":\"S#studyB#R#REVIEWER\"}}"

echo "Seeding items + urgency index (DAY=$DAY)..."
# buckets 0..3 (pra ficar simples no começo)
for i in $(seq 1 10); do
  u=$((RANDOM % 100))
  b=$((i % 4))
  ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  inv=$(python -c "print(f'{9999-$u:04d}')")

  put_item "Items" "{
    \"pk\": {\"S\": \"ITEM#B-Q${i}\"},
    \"sk\": {\"S\": \"META#DataQuery\"},
    \"item_id\": {\"S\": \"B-Q${i}\"},
    \"type\": {\"S\": \"DataQuery\"},
    \"study_id\": {\"S\": \"studyB\"},
    \"urgency\": {\"N\": \"${u}\"},
    \"day\": {\"S\": \"${DAY}\"},
    \"bucket\": {\"N\": \"${b}\"},
    \"updated_at\": {\"S\": \"${ts}\"},
    \"status\": {\"S\": \"OPEN\"},
    \"title\": {\"S\": \"DataQuery - B-Q${i}\"},
    \"version\": {\"N\": \"1\"}
  }"

  put_item "UrgencyIndex" "{
    \"pk\": {\"S\": \"S#studyB#T#DataQuery#D#${DAY}#B#${b}\"},
    \"sk\": {\"S\": \"U#${inv}#TS#${ts}#I#B-Q${i}\"},
    \"study_id\": {\"S\": \"studyB\"},
    \"type\": {\"S\": \"DataQuery\"},
    \"day\": {\"S\": \"${DAY}\"},
    \"bucket\": {\"N\": \"${b}\"},
    \"urgency\": {\"N\": \"${u}\"},
    \"item_id\": {\"S\": \"B-Q${i}\"}
  }"
done

for i in $(seq 1 10); do
  u=$((RANDOM % 100))
  b=$(((i+1) % 4))
  ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  inv=$(python -c "print(f'{9999-$u:04d}')")

  put_item "Items" "{
    \"pk\": {\"S\": \"ITEM#B-S${i}\"},
    \"sk\": {\"S\": \"META#SafetyEvent\"},
    \"item_id\": {\"S\": \"B-S${i}\"},
    \"type\": {\"S\": \"SafetyEvent\"},
    \"study_id\": {\"S\": \"studyB\"},
    \"urgency\": {\"N\": \"${u}\"},
    \"day\": {\"S\": \"${DAY}\"},
    \"bucket\": {\"N\": \"${b}\"},
    \"updated_at\": {\"S\": \"${ts}\"},
    \"status\": {\"S\": \"OPEN\"},
    \"title\": {\"S\": \"SafetyEvent - B-S${i}\"},
    \"version\": {\"N\": \"1\"}
  }"

  put_item "UrgencyIndex" "{
    \"pk\": {\"S\": \"S#studyB#T#SafetyEvent#D#${DAY}#B#${b}\"},
    \"sk\": {\"S\": \"U#${inv}#TS#${ts}#I#B-S${i}\"},
    \"study_id\": {\"S\": \"studyB\"},
    \"type\": {\"S\": \"SafetyEvent\"},
    \"day\": {\"S\": \"${DAY}\"},
    \"bucket\": {\"N\": \"${b}\"},
    \"urgency\": {\"N\": \"${u}\"},
    \"item_id\": {\"S\": \"B-S${i}\"}
  }"
done

echo "Done."
