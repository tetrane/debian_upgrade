#!/bin/bash

USER_ID="$(id -u)"
PSQL_CMD="$(ps -eo command | grep postgres | grep "/tmp/tetrane-$USER_ID")"

if [ "$PSQL_CMD" == "" ]; then
    echo "REVEN doesn't seem to be running. Did you launch \`start.sh\`?"
    exit 1
fi

PSQL_PORT="$(echo "$PSQL_CMD" | rev | cut -d' ' -f 1 | rev)"
PSQL_DIRECTORY="$(echo "$PSQL_CMD" | cut -d' ' -f 3)"
REVEN_VERSION="$(basename "$(dirname "$PSQL_DIRECTORY")")"
BACKUP_FILE="$(dirname "$(dirname "$PSQL_DIRECTORY")")/dump-${REVEN_VERSION}.sql"

echo "REVEN version to backup: ${REVEN_VERSION}"
echo "The database that will be backed up is here: ${PSQL_DIRECTORY}"

read -p "Is this OK? (y/N) " -r ANSWER

case "$ANSWER" in
y*|Y*)
    ;;
*)
    echo "Aborted by user."
    exit 1
    ;;
esac

if ! pg_dumpall -h "/tmp/tetrane-$USER_ID" -p "$PSQL_PORT" > "${BACKUP_FILE}"; then
    echo "The backup failed. Please check the logs above."
    exit 1
fi

echo "Backup successful. Your database dump is here: ${BACKUP_FILE}"
