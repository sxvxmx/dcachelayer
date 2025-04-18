#!/bin/bash
DATA_DIR="data"

service postgresql start

echo "dCache users..."
if [ ! -f /etc/dcache/htpasswd ]; then
    touch /etc/dcache/htpasswd
    htpasswd -bm /etc/dcache/htpasswd tester TooManySecrets
    htpasswd -bm /etc/dcache/htpasswd admin dickerelch
fi

if [ "$1" = 'postgres' ] && [ -z "$(ls -A "$DATA_DIR")" ]; then
    echo "Initializing PostgreSQL database..."
    /usr/pgsql-14/bin/postgresql-14-setup initdb
fi

dcache database update

/chimera-init.sh

dcache start

tail -f /dev/null