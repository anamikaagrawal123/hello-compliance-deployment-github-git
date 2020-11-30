#!/usr/bin/bash

export TARGET_ENVIRONMENT
export HOME
export DEPLOYMENT_DELTA

TARGET_ENVIRONMENT="$(cat /config/environment)"
INVENTORY_PATH="$(cat /config/inventory-path)"
DEPLOYMENT_DELTA_PATH="$(cat /config/deployment-delta-path)"
DEPLOYMENT_DELTA=$(cat "${DEPLOYMENT_DELTA_PATH}")

echo "Target environment: ${TARGET_ENVIRONMENT}"
echo "Deployment Delta (inventory entries with updated artifacts)"
echo ""

echo "$DEPLOYMENT_DELTA" | jq '.'

echo ""
echo "Inventory content"
echo ""

ls -la ${INVENTORY_PATH}

test_count=0

#
# prepare acceptance tests
#
source /root/.nvm/nvm.sh
npm ci

#
# iterate over inventory deployment delta
# and run acceptance tests
#
for INVENTORY_ENTRY in $(echo "${DEPLOYMENT_DELTA}" | jq -r '.[] '); do

  APP_URL_PATH="$(echo ${INVENTORY_ENTRY} | sed 's/\//_/g')_app-url.json"

  export APP_URL=$(cat "../${APP_URL_PATH}")
  npm run acceptance-test
  ((test_count+=1))
done

echo "Run $test_count tests for $(echo "${DEPLOYMENT_DELTA}" | jq '. | length') entries"
