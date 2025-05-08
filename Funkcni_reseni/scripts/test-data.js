db = db.getSiblingDB("mojedb"); // Switch to your database
var filePath = "/docker-entrypoint-initdb.d/narozeni_upravena.csv"; // File path inside the container

// Run mongoimport to import the data from the CSV
var cmd = "mongoimport --uri 'mongodb://root:rootpassword@localhost:27017' --db mojedb --collection narozeni --type csv --headerline --file " + filePath;
var exec = require('child_process').execSync;
exec(cmd);