#!/usr/bin/bash

export IBM_CLOUD_API
export IBMCLOUD_API_KEY
export BREAK_GLASS
export DEPLOYMENT_DELTA
export FILE_LOCATIONS

if [ -f /config/api-key ]; then
  IBMCLOUD_API_KEY="$(cat /config/api-key)" # pragma: allowlist secret
else
  IBMCLOUD_API_KEY="$(cat /config/ibmcloud-api-key)" # pragma: allowlist secret
fi

BREAK_GLASS=$(cat /config/break_glass || echo false)

if [[ -n "$BREAK_GLASS" ]]; then
  echo "Break-Glass mode is on, skipping the rest of the task..."
  exit 0
fi

IBM_CLOUD_API="$(cat /config/ibmcloud-api)"
##########################################################################
# Setting HOME explicitly to have ibmcloud plugins available
# doing the export rather than env definition is a workaround
# until https://github.com/tektoncd/pipeline/issues/1836 is fixed
export HOME="/root"
##########################################################################
if [[ "$IBM_CLOUD_API" == *test* ]]; then
  export IBM_CLOUD_DEVOPS_ENV=dev
fi

TOOLCHAIN_ID=$(cat /config/toolchain-id)
CURRENT_TOOLCHAIN_ID=$(jq -r '.toolchain_guid' /toolchain/toolchain.json)
DOI_IN_TOOLCHAIN=$(jq -e '[.services[] | select(.service_id=="draservicebroker")] | length' /toolchain/toolchain.json)
DOI_ENVIRONMENT=$(cat config/doi-environment)
ENVIRONMENT=$(cat config/environment)
DEPLOYMENT_DELTA_PATH="$(cat /config/deployment-delta-path)"
DEPLOYMENT_DELTA=$(cat "${DEPLOYMENT_DELTA_PATH}")
FILE_LOCATIONS=$(cat /config/file-locations)
TEST_TYPES=$(cat /config/test-types)
INVENTORY_PATH="$(cat /config/inventory-path)"

if [ "$DOI_IN_TOOLCHAIN" == 0 ]; then
  if [ -z "$TOOLCHAIN_ID" ] || [ "$CURRENT_TOOLCHAIN_ID" == "$TOOLCHAIN_ID" ]; then
    echo "No Devops Insights integration found in toolchain. Skipping ..."
    exit 0
  fi
fi

# Default Toolchain ID if needed
if [ -z "$TOOLCHAIN_ID" ]; then
  TOOLCHAIN_ID="$CURRENT_TOOLCHAIN_ID"
fi

# Default Job URL if needed
if [ -z "$JOB_URL" ]; then
  JOB_URL="$PIPELINE_RUN_URL"
fi

if [ "$DOI_ENVIRONMENT" ]; then
  ENVIRONMENT=" --env \"$DOI_ENVIRONMENT\""
elif [ "$ENVIRONMENT" ]; then
  ENVIRONMENT=" --env \"$ENVIRONMENT\""
else
  ENVIRONMENT=""
fi

export TOOLCHAIN_ID=${TOOLCHAIN_ID} # for doi plugin

ibmcloud login --apikey "${IBMCLOUD_API_KEY}" -a "${IBM_CLOUD_API}" --no-region


for INVENTORY_ENTRY in $(echo "${DEPLOYMENT_DELTA}" | jq -r '.[] '); do
  APP=$(cat "${INVENTORY_PATH}/${INVENTORY_ENTRY}")
  APP_NAME=$(echo "${APP}" | jq -r '.name')
  BUILD_NUMBER=$(echo "${APP}" | jq -r '.build_number')

  IFS=';' read -ra locations <<< "$FILE_LOCATIONS"
  IFS=';' read -ra types <<< "$TEST_TYPES"
  for i in "${!locations[@]}"
  do
      echo "$i ${locations[i]} ${types[i]}"
      ibmcloud doi publishtestrecord \
        --logicalappname="$APP_NAME" \
        --buildnumber="$BUILD_NUMBER" \
        --filelocation="${locations[i]}" \
        --type="${types[i]}" "$ENVIRONMENT"
  done
done
