#!/usr/bin/bash

ibmcloud_doi_update_policy() {
  ibmcloud doi policies-update \
    --file "$1" \
    --toolchainid "$2"
}
