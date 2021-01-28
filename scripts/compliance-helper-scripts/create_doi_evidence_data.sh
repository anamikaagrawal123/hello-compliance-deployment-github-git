#!/usr/bin/bash

create_doi_evidence_data() {
  title="$1"
  result="$2"

  task_name=$title

  mkdir -p ./doi-evidence

  DATE=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")

  if [ "$result" = "success" ]; then
    FAILURES=0
    PASSES=1
  else
    FAILURES=1
    PASSES=0
  fi

  full_title="$title - aggregated results"

  TEST_DATA=$(jq --arg key0 "stats" \
      --argjson value0 "{ \
      \"suites\": 1, \
      \"tests\": 1, \
      \"passes\": $PASSES, \
      \"pending\": 0, \
      \"failures\": $FAILURES, \
      \"start\": \"${DATE}\", \
      \"end\": \"${DATE}\" \
    }" \
    --arg key1 "tests" \
    --argjson value1 "[{ \
        \"title\": \"${title}\", \
        \"fullTitle\": \"${full_title}\", \
        \"duration\": 0, \
        \"currentRetry\": 0, \
        \"err\": {} \
    }]" \
    --arg key2 "pending" \
    --argjson value2 "[]" \
    '. | .[$key0]=$value0 | .[$key1]=$value1 | .[$key2]=$value2' \
    <<<'{}')

  if [ "$result" = "success" ]; then
    TEST_DATA=$(echo "$TEST_DATA" | jq ".passes += [
      {
        \"title\": \"${title}\", \
        \"fullTitle\": \"${full_title}\", \
        \"duration\": 0, \
        \"currentRetry\": 0, \
        \"err\": {} \
      }
    ]")
    TEST_DATA=$(echo "$TEST_DATA" | jq ".failures += []")
  else
    TEST_DATA=$(echo "$TEST_DATA" | jq ".failures += [
      {
        \"title\": \"${title}\", \
        \"fullTitle\": \"${full_title}\", \
        \"duration\": 0, \
        \"currentRetry\": 0, \
        \"err\": {} \
      }
    ]")
    TEST_DATA=$(echo "$TEST_DATA" | jq ".passes += []")
  fi

  FILENAME="./doi-evidence/$task_name-evidence.json"

  echo "$TEST_DATA" > "$FILENAME"

  echo "$FILENAME"
}
