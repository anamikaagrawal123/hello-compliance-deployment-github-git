#!/usr/bin/bash

create_pipeline_task_url() {
  pipeline_run_url="$1"
  task_name="$2"
  step_name="$3"

  url=$(echo "$pipeline_run_url" | sed -E "s/\/?(\?.*)/\/$task_name\1/")

  if [ -n "$step_name" ]; then
    url=$(echo "$url" | sed -E "s/\/?(\?.*)/\/$step_name\1/")
  fi

  echo "$url"
}
