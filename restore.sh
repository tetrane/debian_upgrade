#!/bin/bash

DB_PATH="$1"
DUMP_PATH="$2"
USER_ID="$(id -u)"
PSQL_PORT=44444 # Change this if you happen to have something running here
SOCKET_PATH="/tmp/reven-restore-$USER_ID"
LOG_DIR=/tmp/reven-restore-logs

mkdir -p "$SOCKET_PATH" "$LOG_DIR"

function usage() {
    echo "Usage: $(basename "$0") path/to/database.psql path/to/dump.sql"
    exit 1
}

if ! [ -f "$DUMP_PATH" ]; then
    echo "The dump file you provided seems wrong: $DUMP_PATH"
    usage
fi

if [ "$(cat "$DB_PATH"/PG_VERSION 2>/dev/null)" != "9.6" ] ; then
    echo "The database folder you provided seems wrong: $DB_PATH"
    echo "Either it is not a PostgreSQL database, or it is the wrong version. Expected version is 9.6 (Stretch)."
    usage
fi

echo "This script will regenerate the database with the provided dump."
echo "  Database: $DB_PATH"
echo "  Dump: $DUMP_PATH"

read -p "Is this OK? (y/N) " -r ANSWER
case "$ANSWER" in
y*|Y*)
    ;;
*)
    echo "Aborted by user."
    exit 1
    ;;
esac

echo "You will find all the log files here: $LOG_DIR"

# Ensure the DB path exists
mkdir -p "$DB_PATH"

# Clean the old database
echo "Cleaning old database."
rm "$DB_PATH/"* -rf

# Init the DB
echo "Initializing the database. Log file: $LOG_DIR/initdb.log"
if ! /usr/lib/postgresql/11/bin/initdb "$DB_PATH" >"$LOG_DIR/initdb.log" 2>&1; then
    echo "Error while creating the DB. Please check the logs."
    exit 1
fi

# Start postgres
echo "Starting postgres. Log file: $LOG_DIR/postgres.log"
/usr/lib/postgresql/11/bin/postgres -D "$DB_PATH" -k "$SOCKET_PATH" -p "$PSQL_PORT" >"$LOG_DIR/postgres.log" 2>&1 &
psql_pid=$!

while ! test -S "$SOCKET_PATH/.s.PGSQL.$PSQL_PORT"; do
    echo "Waiting for postgres to start up."
    sleep 0.1
done

# Restore the dump and select the 'postgres' DB
echo "Restoring the dump. Log file: $LOG_DIR/psql.log"
if ! psql -h "$SOCKET_PATH" -p "$PSQL_PORT" postgres < "$DUMP_PATH" >"$LOG_DIR/psql.log" 2>&1; then
    echo "Error while restoring the DB. Please check the logs."
    exit 1
fi

# Shutdown postgres
kill -2 "$psql_pid"

while test -S "$SOCKET_PATH/.s.PGSQL.$PSQL_PORT"; do
    echo "Waiting for postgres to shut down."
    sleep 0.1
done

rmdir "$SOCKET_PATH"

echo "Success."
