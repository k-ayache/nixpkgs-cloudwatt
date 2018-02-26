#!/usr/bin/env bash

COOKIE_FILE="hydra-cookie.txt"

HYDRA_ADMIN_USERNAME=${HYDRA_ADMIN_USERNAME:-admin}
HYDRA_ADMIN_PASSWORD=${HYDRA_ADMIN_PASSWORD:-admin}
URL=${URL:-http://localhost:3000}

if [[ $# -ne 2 ]]; then
    echo "Usage: $0 { restart-aborted, restart-failed, cancel } EVAL-NUMBER"
    exit 1
fi

EVAL_NUMBER=$2
ACTION=$1

mycurl () {
    curl $@ > /dev/null
    RET=$?
    if [[ $RET -ne 0 ]]; then
        echo " failed"
    else
        echo " done"
    fi
}

cat >.data.json <<EOF
{ "username": "$HYDRA_ADMIN_USERNAME", "password": "$HYDRA_ADMIN_PASSWORD" }
EOF

echo "Logging to $URL"
curl --silent --referer $URL -H "Accept: application/json" -H "Content-Type: application/json" -X POST -d '@.data.json' $URL/login -c $COOKIE_FILE > /dev/null

echo -n "$ACTION on eval $EVAL_NUMBER ..."
mycurl -f --silent $URL/eval/$EVAL_NUMBER/$ACTION -b $COOKIE_FILE

rm -f .data.json $COOKIE_FILE
