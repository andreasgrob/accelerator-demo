#!/usr/bin/env bash
set -e              #fail script when an instruction fails
set -o pipefail     #fails script a piped instruction fails
set -u              #fail script when a variable is uninitialised

VALUESFILE="./environment.yaml"
GCP_PROJECT_ID=$(yq e  ".gcp-project-id" $VALUESFILE)

gcloud projects delete $GCP_PROJECT_ID
