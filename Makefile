.PHONY: up down tables seed run test

up:
	docker compose up -d

down:
	docker compose down

tables:
	chmod +x scripts/create_tables.sh && ./scripts/create_tables.sh

seed:
	chmod +x scripts/seed_data.sh && ./scripts/seed_data.sh

run:
	DYNAMO_ENDPOINT=http://localhost:4566 uvicorn app.main:app --reload

test:
	python -m compileall app
