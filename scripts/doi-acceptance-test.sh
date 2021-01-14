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

if [[ "$BREAK_GLASS" != "false" ]]; then
  echo "Break-Glass mode is on, skipping the rest of the task..."
  exit 0
fi

##########################################################################
# Setting HOME explicitly to have ibmcloud plugins available
# doing the export rather than env definition is a workaround
# until https://github.com/tektoncd/pipeline/issues/1836 is fixed
export HOME="/root"
##########################################################################

IBM_CLOUD_API=$(cat /config/ibmcloud-api || echo "https://cloud.ibm.com")
TOOLCHAIN_ID=$(cat /config/doi-toolchain-id)
CURRENT_TOOLCHAIN_ID=$(jq -r '.toolchain_guid' /toolchain/toolchain.json)
DOI_IN_TOOLCHAIN=$(jq -e '[.services[] | select(.service_id=="draservicebroker")] | length' /toolchain/toolchain.json)
DOI_ENVIRONMENT=$(cat /config/doi-environment)
ENVIRONMENT=$(cat /config/environment)
DEPLOYMENT_DELTA_PATH=$(cat /config/deployment-delta-path)
DEPLOYMENT_DELTA=$(cat "${DEPLOYMENT_DELTA_PATH}")
INVENTORY_PATH=$(cat /config/inventory-path)

if [[ "$IBM_CLOUD_API" == *test* ]]; then
  export IBM_CLOUD_DEVOPS_ENV=dev
fi

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

source scripts/compliance-helper-scripts/create_pipeline_task_url.sh
source scripts/compliance-helper-scripts/create_doi_dataset_file.sh
source scripts/compliance-helper-scripts/ibmcloud_doi_update_policy.sh
source scripts/compliance-helper-scripts/create_doi_evidence_data.sh

export TOOLCHAIN_ID=${TOOLCHAIN_ID} # for doi plugin

ibmcloud login --apikey "${IBMCLOUD_API_KEY}" -a "${IBM_CLOUD_API}" --no-region
ibmcloud plugin update doi --force

echo ""

TASK_NAME="prod-acceptance-tests"
STEP_NAME=""
EVIDENCE_TYPE="com.ibm.acceptance_tests"

echo "Processing $TASK_NAME/$STEP_NAME ..."
echo ""

#
# Create DOI dataset
#

DATASET_FILE_PATH="./doi-evidence/doi-dataset-$TASK_NAME.json"
DATASET_LABEL="Evidence of $EVIDENCE_TYPE"
DATASET_NAME="compliance-${TASK_NAME}"
DATASET_FILE=$(create_doi_dataset_file "$DATASET_FILE_PATH" "$DATASET_LABEL" "$DATASET_NAME")

ibmcloud_doi_update_policy "$DATASET_FILE" "$TOOLCHAIN_ID"

#
# Create DOI evidence data
#

RESULT="failure"
if [ "$EXIT" -eq "0" ]; then
RESULT="success"
fi

EVIDENCE_DATA_FILE=$(create_doi_evidence_data "$TASK_NAME" "$RESULT")

#
# Publish data to DOI
#

URL=$(create_pipeline_task_url "$PIPELINE_RUN_URL" "$TASK_NAME" "$STEP_NAME")

for INVENTORY_ENTRY in $(echo "${DEPLOYMENT_DELTA}" | jq -r '.[] '); do
  APP=$(cat "${INVENTORY_PATH}/${INVENTORY_ENTRY}")
  APP_NAME=$(echo "${APP}" | jq -r '.name')
  BUILD_NUMBER=$(echo "${APP}" | jq -r '.build_number')

  ibmcloud doi publishtestrecord \
    --toolchainid="$TOOLCHAIN_ID" \
    --logicalappname="$APP_NAME" \
    --buildnumber="$BUILD_NUMBER" \
    --filelocation="${EVIDENCE_DATA_FILE}" \
    --type="${DATASET_NAME}" \
    --drilldownurl="${URL}" \
    "$ENVIRONMENT"

    echo ""
done
