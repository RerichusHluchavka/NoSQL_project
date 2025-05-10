#!/bin/sh

use mojedb;

db.createCollection("narozeni");
db.createCollection("nadeje");
db.createCollection("plodnost");

sh.enableSharding("mojedb");

sh.shardCollection("mojedb.narozeni", { "Uz01A": 1 });
sh.shardCollection("mojedb.nadeje", { "Uz01A": 1 });
sh.shardCollection("mojedb.plodnost", { "Uz01A": 1 });


