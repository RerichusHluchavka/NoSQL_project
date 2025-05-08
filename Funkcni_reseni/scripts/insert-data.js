#!/bin/bash

mongosh <<EOF
use mojedb; 

db.createCollection("narozeni");
db.createCollection("nadeje");
db.createCollection("plodnost");

sh.enableSharding("mojedb");

sh.shardCollection("mojedb.narozeni", { "Uz01A": 1 });
sh.shardCollection("mojedb.nadeje", { "Uz01A": 1 });
sh.shardCollection("mojedb.plodnost", { "Uz01A": 1 });

!mongoimport --uri "mongodb://root:rootpassword@mongo:27017" --db mojedb --collection narozeni --type csv --headerline --file ../Data/narozeni_upravena.csv;

!mongoimport --uri "mongodb://root:rootpassword@mongo:27017" --db mojedb --collection nadeje --type csv --headerline --file ../Data/nadeje.csv;

!mongoimport --uri "mongodb://root:rootpassword@mongo:27017" --db mojedb --collection plodnost --type csv --headerline --file ../Data/narozeni_upravene.csv;

exit;
EOF
