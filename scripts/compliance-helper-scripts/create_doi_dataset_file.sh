#!/usr/bin/bash

create_doi_dataset_file() {
  file_path=$1
  label=$2
  lifecycle_stage=$3

  mkdir -p ./doi-evidence

  DATASET_FILE="$file_path"
  DATASET_JSON=$(jq \
    --arg key0 "custom_datasets" \
    --argjson value0 "[{ \
        \"lifecycle_stage\": \"${lifecycle_stage}\", \
        \"type_of_test\": \"test\", \
        \"label\": \"${label}\" \
    }]" \
    --arg key1 "policies" \
    --argjson value1 "[]" \
    '. | .[$key0]=$value0 | .[$key1]=$value1' \
    <<<'{}')

  echo "$DATASET_JSON" > "${DATASET_FILE}"

  echo "${DATASET_FILE}"
}
