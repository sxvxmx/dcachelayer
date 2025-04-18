#!/bin/bash
DATA_DIR="data"

service postgresql start

if [ "$1" = 'postgres' ] && [ -z "$(ls -A "$DATA_DIR")" ]; then
    echo "Initializing PostgreSQL database..."
    /usr/pgsql-13/bin/postgresql-13-setup initdb
fi

dcache database update

echo "db DONE"

tail -f /dev/null