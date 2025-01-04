#!/bin/bash

cleanup() {
    echo "Stopping application..."

    docker compose down

    # Kill the background jobs started in this script
    if [[ -n "$CONSOLE_PID" ]]; then
        echo "Stopping Console Application (PID: $CONSOLE_PID)..."
        kill "$CONSOLE_PID" 2>/dev/null && wait "$CONSOLE_PID" 2>/dev/null
    fi

    if [[ -n "$PSQL_PID" ]]; then
        echo "Stopping PostgreSQL Flask service (PID: $PSQL_PID)..."
        kill "$PSQL_PID" 2>/dev/null && wait "$PSQL_PID" 2>/dev/null
    fi

    if [[ -n "$REDIS_PID" ]]; then
        echo "Stopping Redis Flask service (PID: $REDIS_PID)..."
        kill "$REDIS_PID" 2>/dev/null && wait "$REDIS_PID" 2>/dev/null
    fi

    if [[ -n "$MONGODB_PID" ]]; then
        echo "Stopping MongoDB Flask service (PID: $MONGODB_PID)..."
        kill "$MONGODB_PID" 2>/dev/null && wait "$MONGODB_PID" 2>/dev/null
    fi

    if [[ -n "$CASSANDRA_PID" ]]; then
        echo "Stopping Cassandra Flask service (PID: $CASSANDRA_PID)..."
        kill "$CASSANDRA_PID" 2>/dev/null && wait "$CASSANDRA_PID" 2>/dev/null
    fi

    echo "Application stopped."
}

trap cleanup SIGINT SIGTERM

echo "Starting Docker..."
if !systemctl is-active --quiet docker; then
    sudo service docker start
fi

docker compose up -d
echo "Waiting for Cassandra to become available..."
until docker exec cassandra cqlsh -e "SHOW VERSION" >/dev/null 2>&1; do
    echo "Cassandra is not ready yet. Retrying in 5 seconds..."
    sleep 5
done

echo "Setting up databases..."
. db_init/db_init.sh

echo "Starting PostgreSQL Flask service..."
python src/psql_service/psql_service.py &
PSQL_PID=$!

echo "Starting Redis Flask service..."
python src/redis_service/redis_service.py &
REDIS_PID=$!

echo "Starting MongoDB Flask service..."
python src/mongodb_service/mongodb_service.py &
MONGODB_PID=$!

echo "Starting Cassandra Flask service..."
python src/cassandra_service/cassandra_service.py &
CASSANDRA_PID=$!

sleep 3
echo "Starting Console Application..."
python -i src/console_app.py
APP_PID=$!

cleanup