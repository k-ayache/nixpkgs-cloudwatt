#!/usr/bin/env bash

# Usage example
# URL=http://localhost:30000 bash ci/create-project.sh

set -e

USERNAME=${USERNAME:-admin}
PASSWORD=${PASSWORD:-admin}
PROJECT_NAME="cloudwatt"
JOBSET_NAME="trunk"
URL=${URL:-http://localhost:3000}

mycurl() {
  curl --referer $URL -H "Accept: application/json" -H "Content-Type: application/json" $@
}

echo "Logging to $URL with user" "'"$USERNAME"'"
cat >data.json <<EOF
{ "username": "$USERNAME", "password": "$PASSWORD" }
EOF
mycurl -X POST -d '@data.json' $URL/login -c hydra-cookie.txt

echo -e "\nCreating project:"
cat >data.json <<EOF
{
  "displayname":"Cloudwatt Hydra CI",
  "enabled":"1"
}
EOF
cat data.json
mycurl --silent -X PUT $URL/project/$PROJECT_NAME -d @data.json -b hydra-cookie.txt

echo -e "\nCreating jobset trunk:"
cat >data.json <<EOF
{
  "description": "Build master of nixpkgs-cloudwatt",
  "checkinterval": "60",
  "enabled": "1",
  "visible": "1",
  "nixexprinput": "cloudwatt",
  "nixexprpath": "jobset.nix",
  "inputs": {
    "cloudwatt": {
      "value": "https://github.com/nlewo/nixpkgs-cloudwatt master keepDotGit",
      "type": "git"
    },
    "bootstrap_pkgs": {
      "value": "https://github.com/NixOS/nixpkgs a0e6a891ee21a6dcf3da35169794cc20b110ce05",
      "type": "git"
    },
    "pushToDockerRegistry": {
      "value": "true",
      "type": "boolean"
    },
    "publishToAptly": {
      "value": "true",
      "type": "boolean"
    }
  }
}
EOF
cat data.json
mycurl --silent -X PUT $URL/jobset/$PROJECT_NAME/$JOBSET_NAME -d @data.json -b hydra-cookie.txt


JOBSET_NAME="staging"
echo -e "\nCreating jobset staging:"
cat >data.json <<EOF
{
  "description": "Build master of nixpkgs-cloudwatt and nixpkgs-contrail",
  "checkinterval": "60",
  "enabled": "1",
  "visible": "1",
  "nixexprinput": "cloudwatt",
  "nixexprpath": "jobset.nix",
  "inputs": {
    "cloudwatt": {
      "value": "https://github.com/nlewo/nixpkgs-cloudwatt master keepDotGit",
      "type": "git"
    },
    "bootstrap_pkgs": {
      "value": "https://github.com/NixOS/nixpkgs a0e6a891ee21a6dcf3da35169794cc20b110ce05",
      "type": "git"
    },
    "contrail": {
      "value": "https://github.com/nlewo/nixpkgs-contrail master",
      "type": "git"
    }
  }
}
EOF
cat data.json
mycurl --silent -X PUT $URL/jobset/$PROJECT_NAME/$JOBSET_NAME -d @data.json -b hydra-cookie.txt

JOBSET_NAME="testing"
echo -e "\nCreating jobset testing:"
cat >data.json <<EOF
{
  "description": "Build testing branch of nixpkgs-cloudwatt",
  "checkinterval": "60",
  "enabled": "1",
  "visible": "1",
  "nixexprinput": "cloudwatt",
  "nixexprpath": "jobset.nix",
  "inputs": {
    "cloudwatt": {
      "value": "https://github.com/nlewo/nixpkgs-cloudwatt testing keepDotGit",
      "type": "git"
    },
    "bootstrap_pkgs": {
      "value": "https://github.com/NixOS/nixpkgs a0e6a891ee21a6dcf3da35169794cc20b110ce05",
      "type": "git"
    }
  }
}
EOF
cat data.json
mycurl --silent -X PUT $URL/jobset/$PROJECT_NAME/$JOBSET_NAME -d @data.json -b hydra-cookie.txt

rm -f data.json hydra-cookie.txt
