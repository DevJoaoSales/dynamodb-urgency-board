#!/usr/bin/env bash
set -euo pipefail

AWS_REGION="${AWS_DEFAULT_REGION:-us-east-1}"
ENDPOINT_URL="${ENDPOINT_URL:-http://localhost:4566}"

echo "Creating DynamoDB tables on LocalStack..."

create () {
  local name="$1"
  aws dynamodb create-table \
    --table-name "$name" \
    --attribute-definitions \
      AttributeName=pk,AttributeType=S \
      AttributeName=sk,AttributeType=S \
    --key-schema \
      AttributeName=pk,KeyType=HASH \
      AttributeName=sk,KeyType=RANGE \
    --billing-mode PAY_PER_REQUEST \
    --region "${AWS_REGION}" \
    --endpoint-url "${ENDPOINT_URL}" >/dev/null || true
}

create "Items"
create "UrgencyIndex"
create "Access"

echo "Done. Current tables:"
aws dynamodb list-tables --region "${AWS_REGION}" --endpoint-url "${ENDPOINT_URL}"
