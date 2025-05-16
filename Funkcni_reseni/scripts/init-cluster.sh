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

docker exec mongo-config-01 bash "/scripts/auth.js"
docker exec shard-01-node-a bash "/scripts/auth.js"
docker exec shard-02-node-a bash "/scripts/auth.js"
docker exec shard-03-node-a bash "/scripts/auth.js"

echo "Cluster ready"

echo "Preparing database..."
docker exec router-01 mongosh --username admin --password admin --port 27017 --authenticationDatabase admin --eval '

    db = db.getSiblingDB("mojedb");

    sh.enableSharding("mojedb");

    const commonSchema = {
        bsonType: "object",
        required: ["Ukazatel", "IndicatorType", "Roky", "Hodnota", "Uz01A"],
        properties: {
            Ukazatel: {
            bsonType: ["string", "int"],
            description: "Název ukazatele"
            },
            IndicatorType: {
            bsonType: ["string", "int"],
            description: "Indikátor ukazatele"
            },
            Roky: {
            bsonType: "int",
            minimum: 1900,
            maximum: 2100,
            description: "Roky záznamu"
            },
            Uz01A: {
            bsonType: "string",
            pattern: "^CZ(0[1-8])?$",
            description: "Kód regionu"
            },
            Hodnota: {
            bsonType: ["double", "int"],
            description: "Hodnota záznamu"
            }
        }
    };

    const birthSchema = {
        $jsonSchema: {
            ...commonSchema,
            required: [...commonSchema.required, "Oblast", "Uz012"],
            properties: {
                ...commonSchema.properties,
                Oblast: {
                    bsonType: "string",
                    description: "Název regionální oblasti"
                },
                Uz012: {
                    bsonType: "string",
                    pattern: "^CZ((0[0-9][0-9])|(0[1-8]))?$",
                    description: "Kód regionální oblasti"
                }
            }
        }
    };

    const hopeSchema = {
        $jsonSchema: {
            ...commonSchema,
            required: [...commonSchema.required, "ČR, regiony", "Pohlaví", "POHZM", "Věk (roky)", "VEK1UT"],
            properties: {
                ...commonSchema.properties,
                "ČR, regiony": {
                    bsonType: "string",
                    description: "Název regionu"
                },
                Pohlaví: {
                    bsonType: "string",
                    pattern: "^(ženy|muži)$",
                    description: "Pohlaví"
                },
                POHZM: {
                    bsonType: "int",
                    description: "Kód pohlaví"
                },
                "Věk (roky)": {
                    bsonType: "int",
                    minimum: 0,
                    maximum: 120,
                    description: "Věk v letech"
                },
                VEK1UT: {
                    bsonType: "long",
                    description: "Kód věku"
                }
            }
        }
    };

    const fertilitySchema = {
        $jsonSchema: {
            ...commonSchema,
            required: [...commonSchema.required, "Oblast", "Uz012", "Věk (jednoleté skupiny)", "VEKZEN1PLOD"],
            properties: {
                ...commonSchema.properties,
                Oblast: {
                    bsonType: "string",
                    description: "Název regionální oblasti"
                },
                Uz012: {
                    bsonType: "string",
                    pattern: "^CZ((0[0-9][0-9])|(0[1-8]))?$",
                    description: "Kód regionální oblasti"
                },
                "Věk (jednoleté skupiny)": {
                    bsonType: "int",
                    minimum: 0,
                    maximum: 120,
                    description: "Věk zaznamenávané skupiny v letech"
                },
                VEKZEN1PLOD: {
                    bsonType: "long",
                    description: "Kód věku"
                }
            }
        }
    };

    db.createCollection("narozeni", {
    validator: birthSchema,
    validationLevel: "strict",
    validationAction: "error"
    });

    db.createCollection("nadeje", {
    validator: hopeSchema,
    validationLevel: "strict",
    validationAction: "error"
    });

    db.createCollection("plodnost", {
    validator: fertilitySchema,
    validationLevel: "strict",
    validationAction: "error"
    });

    db.narozeni.createIndex({ "Uz01A": 1 });
    db.narozeni.createIndex({"Roky": 1});

    db.nadeje.createIndex({ "Uz01A": 1 });
    db.nadeje.createIndex({"Roky": 1});

    db.plodnost.createIndex({ "Uz01A": 1 });
    db.plodnost.createIndex({"Roky": 1});

    sh.shardCollection("mojedb.narozeni", {  "Hodnota": 1, "Uz01A": 1 });
    sh.shardCollection("mojedb.nadeje", { "Hodnota": 1, "Uz01A": 1 });
    sh.shardCollection("mojedb.plodnost", { "Hodnota": 1, "Uz01A": 1 });

    '

echo "Database mojedb created and collections initialized."
echo "Inserting data into collections..."

echo "Importing narozeni"
docker exec router-01 mongoimport --username admin --password admin --authenticationDatabase admin --db mojedb --collection narozeni --type csv --headerline --file /Data/narozeni_upravena.csv

echo "Importing nadeje"
docker exec router-01 mongoimport --username admin --password admin --authenticationDatabase admin --db mojedb --collection nadeje --type csv --headerline --file /Data/nadeje_upravena.csv

echo "Importing plodnost"
docker exec router-01 mongoimport --username admin --password admin --authenticationDatabase admin --db mojedb --collection plodnost --type csv --headerline --file /Data/plodnost_upravena.csv 

echo "Setting chunk size to 1MB to show sharding"
docker exec router-01 mongosh --username admin --password admin --authenticationDatabase admin --eval 'db.getSiblingDB("config").settings.updateOne({ _id: "chunksize" }, { $set: { value: 1 } }, { upsert: true },{ upsert: true })'
echo "✅ Data imported successfully."
exit 0
