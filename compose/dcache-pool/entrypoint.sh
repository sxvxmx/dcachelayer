#!/bin/bash
sleep 20

echo "dCache pool..."
mkdir -p /srv/dcache/
dcache pool create /srv/dcache/pool-1 pool1 poolsDomain || echo "Pool might already exist"

dcache start

tail -f /dev/null