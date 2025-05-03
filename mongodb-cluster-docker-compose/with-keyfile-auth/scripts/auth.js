#!/bin/bash

mongosh <<EOF
use admin;
db.createUser({user: "admin", pwd: "admin", roles:[{role: "root", db: "admin"}]});
exit;
EOF