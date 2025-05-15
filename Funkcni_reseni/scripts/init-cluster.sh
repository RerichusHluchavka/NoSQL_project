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

    echo "Cluster ready"

    echo "Preparing database..."
    docker exec router-01 mongosh --username admin --password admin  --port 27017 --authenticationDatabase admin --eval '

    // Create database and collections
    db = db.getSiblingDB("mojedb");

    // Enable sharding for the database
    sh.enableSharding("mojedb");

    // Create collections
    db.createCollection("narozeni");
    db.createCollection("nadeje");
    db.createCollection("plodnost");

    // Shard collections
    sh.shardCollection("mojedb.narozeni", {  "Hodnota": 1, "Uz01A": 1 });
    sh.shardCollection("mojedb.nadeje", { "Hodnota": 1, "Uz01A": 1 });
    sh.shardCollection("mojedb.plodnost", { "Hodnota": 1, "Uz01A": 1 });
    '
    echo "Database mojedb created and collections initialized."
    echo "Inserting data into collections..."


    echo "Importing narozeni"
    docker exec router-01 mongoimport --username admin --password admin --authenticationDatabase admin --db mojedb --collection narozeni --type csv --headerline --file /Data/narozeni_upravena.csv
    
    echo "Importing nadeje"
    docker exec router-01 mongoimport --username admin --password admin --authenticationDatabase admin --db mojedb --collection nadeje --type csv --headerline --file /Data/nadeje.csv
    
    echo "Importing plodnost"
    docker exec router-01 mongoimport --username admin --password admin --authenticationDatabase admin --db mojedb --collection plodnost --type csv --headerline --file /Data/plodnost_upravena.csv

    echo "Setting chunk size to 1MB to show sharding"
    docker exec router-01 mongosh --username admin --password admin --authenticationDatabase admin --eval 'db.getSiblingDB("config").settings.updateOne({ _id: "chunksize" }, { $set: { value: 1 } }, { upsert: true },{ upsert: true })'
    echo "✅ Data imported successfully."
    exit 0
    
db.settings.updateOne({ _id: "chunksize" },{ $set: { _id: "chunksize", value: 1 } },{ upsert: true })