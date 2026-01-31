#!/usr/bin/env bash
set -euo pipefail

AWS_REGION="${AWS_REGION:-us-east-1}"
ENDPOINT_URL="${ENDPOINT_URL:-http://localhost:4566}"

echo "Creating DynamoDB tables on LocalStack..."
echo "Region: ${AWS_REGION}"
echo "Endpoint: ${ENDPOINT_URL}"

aws dynamodb create-table \
  --table-name Items \
  --attribute-definitions \
    AttributeName=pk,AttributeType=S \
    AttributeName=sk,AttributeType=S \
  --key-schema \
    AttributeName=pk,KeyType=HASH \
    AttributeName=sk,KeyType=RANGE \
  --billing-mode PAY_PER_REQUEST \
  --region "${AWS_REGION}" \
  --endpoint-url "${ENDPOINT_URL}" \
  >/dev/null || true

aws dynamodb create-table \
  --table-name UrgencyIndex \
  --attribute-definitions \
    AttributeName=pk,AttributeType=S \
    AttributeName=sk,AttributeType=S \
  --key-schema \
    AttributeName=pk,KeyType=HASH \
    AttributeName=sk,KeyType=RANGE \
  --billing-mode PAY_PER_REQUEST \
  --region "${AWS_REGION}" \
  --endpoint-url "${ENDPOINT_URL}" \
  >/dev/null || true

aws dynamodb create-table \
  --table-name Access \
  --attribute-definitions \
    AttributeName=pk,AttributeType=S \
    AttributeName=sk,AttributeType=S \
  --key-schema \
    AttributeName=pk,KeyType=HASH \
    AttributeName=sk,KeyType=RANGE \
  --billing-mode PAY_PER_REQUEST \
  --region "${AWS_REGION}" \
  --endpoint-url "${ENDPOINT_URL}" \
  >/dev/null || true

echo "Done. Current tables:"
aws dynamodb list-tables \
  --region "${AWS_REGION}" \
  --endpoint-url "${ENDPOINT_URL}"
