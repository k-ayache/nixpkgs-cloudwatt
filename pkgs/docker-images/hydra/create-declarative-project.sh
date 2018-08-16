#!/usr/bin/env bash

# Usage example
# URL=http://localhost:30000 bash ci/create-project.sh

set -e

HYDRA_ADMIN_USERNAME=${HYDRA_ADMIN_USERNAME:-admin}
HYDRA_ADMIN_PASSWORD=${HYDRA_ADMIN_PASSWORD:-admin}
URL=${URL:-http://localhost:3000}
DECL_FILE=${DECL_FILE:-"ci/spec.json"}
DECL_TYPE=${DECL_TYPE:-"git"}
DECL_VALUE=${DECL_VALUE:-"https://github.com/nlewo/nixpkgs-cloudwatt master keepDotGit"}

DECL_PROJECT_NAME="cloudwatt"

mycurl() {
  curl --referer $URL -H "Accept: application/json" -H "Content-Type: application/json" $@
}

echo "Logging to $URL with user" "'"$HYDRA_ADMIN_USERNAME"'"
cat >data.json <<EOF
{ "username": "$HYDRA_ADMIN_USERNAME", "password": "$HYDRA_ADMIN_PASSWORD" }
EOF
mycurl -X POST -d '@data.json' $URL/login -c hydra-cookie.txt

echo -e "\nCreating project:"
cat >data.json <<EOF
{
  "displayname":"Cloudwatt Hydra CI",
  "enabled":"1",
  "declfile": "$DECL_FILE",
  "decltype":"$DECL_TYPE",
  "declvalue":"$DECL_VALUE"
}
EOF
cat data.json
mycurl --silent -X PUT $URL/project/$DECL_PROJECT_NAME -d @data.json -b hydra-cookie.txt

rm -f data.json hydra-cookie.txt
