#!/usr/bin/env bash
set -e              #fail script when an instruction fails
set -o pipefail     #fails script a piped instruction fails
set -u              #fail script when a variable is uninitialised

VALUESFILE="./environment.yaml"
GCP_PROJECT_ID=$(yq e  ".gcp-project-id" $VALUESFILE)
GCP_ZONE=$(yq e ".gcp-zone" $VALUESFILE)

gcloud beta compute ssh --zone $GCP_ZONE $1 --tunnel-through-iap --project $GCP_PROJECT_ID
