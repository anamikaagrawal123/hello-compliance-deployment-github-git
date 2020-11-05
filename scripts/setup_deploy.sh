#!/usr/bin/bash

export IBMCLOUD_API_KEY
export IBMCLOUD_IKS_REGION
export IBMCLOUD_IKS_CLUSTER_NAME
export IBMCLOUD_IKS_CLUSTER_NAMESPACE
export REGISTRY_URL
export IMAGE_PULL_SECRET_NAME
export TARGET_ENVIRONMENT
export IMAGE

if [ -f /config/api-key ]; then
  IBMCLOUD_API_KEY="$(cat /config/api-key)" # pragma: allowlist secret
else
  IBMCLOUD_API_KEY="$(cat /config/ibmcloud-api-key)" # pragma: allowlist secret
fi

IBMCLOUD_IKS_REGION="$(cat /config/dev-region | awk -F ":" '{print $NF}')"
IBMCLOUD_IKS_CLUSTER_NAMESPACE="$(cat /config/dev-cluster-namespace)"
IBMCLOUD_IKS_CLUSTER_NAME="$(cat /config/cluster-name)"
IMAGE_PULL_SECRET_NAME="ibmcloud-toolchain-${IBMCLOUD_TOOLCHAIN_ID}-${REGISTRY_URL}"

TARGET_ENVIRONMENT="$(cat /config/environment)"
INVENTORY_PATH="$(cat /config/inventory-path)"
DEPLOYMENT_DELTA_PATH="$(cat /config/deployment-delta-path)"

echo "Target environment: ${TARGET_ENVIRONMENT}"
echo "Deployment Delta (inventory entries with updated artifacts)"
echo ""

cat "${DEPLOYMENT_DELTA_PATH}" | jq '.'

echo ""
echo "Inventory content"
echo ""

ls -la ${INVENTORY_PATH}

APP=$(cat "${DEPLOYMENT_DELTA_PATH}" | jq -r '.[0] // ""')

if [ -z $APP ]; then
  APP="hello-compliance-app"
fi

ARTIFACT=$(cat "${INVENTORY_PATH}/$APP" | jq -r '.artifact')
REGISTRY_URL="$(echo $ARTIFACT | awk -F/ '{print $1}')"
IMAGE="$REGISTRY_URL/$(echo $ARTIFACT | awk -F "/|@" '{print $2"/"$3"@"$4}')"

echo $ARTIFACT
echo $REGISTRY_URL
echo $IMAGE

echo ""
echo "Deploying $APP..."
echo ""
