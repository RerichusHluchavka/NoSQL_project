#!/bin/sh
    set -e
    echo 'Starting initialization...' 

    docker exec mongo-config-01 bash "/scripts/init-configserver.js"
    sleep 1

    echo 'configsvr01 initialized'
    sleep 1 
    docker exec shard-01-node-a bash "/scripts/init-shard01.js"
    echo 'shard01-a initialized'
    sleep 1 
    docker exec shard-02-node-a bash "/scripts/init-shard02.js"
    echo 'shard02-a initialized'
    sleep 1 
    docker exec shard-03-node-a bash "/scripts/init-shard03.js"
    echo 'shard03-a initialized'

    echo 'Waiting 10 seconds for router01 to stabilize...' 
    sleep 10

    docker exec router-01 sh -c "mongosh < /scripts/init-router.js"
    echo 'router01 initialized'

    echo 'Setting up authentication...' 
    docker exec  mongo-config-01 bash "/scripts/auth.js" 
    docker exec  shard-01-node-a bash "/scripts/auth.js"
    docker exec  shard-02-node-a bash "/scripts/auth.js" 
    docker exec  shard-03-node-a bash "/scripts/auth.js" 

    echo "✅ Cluster ready!"
    exit 0
    