#!/usr/bin/env bash
set -e              #fail script when an instruction fails
set -o pipefail     #fails script a piped instruction fails
set -u              #fail script when a variable is uninitialised

VALUESFILE="./environment.yaml"
GCP_USER_LABEL=$(gcloud info --format="value(config.account)" | cut -d@ -f1)
GCP_PROJECT_ID=$(yq e  ".gcp-project-id" $VALUESFILE)
GCP_FOLDER_ID=$(yq e  ".gcp-folder-id" $VALUESFILE)
GCP_REGION=$(yq e ".gcp-region" $VALUESFILE)
GCP_ZONE=$(yq e ".gcp-zone" $VALUESFILE)
INSTALLER_URL=$(yq e ".installer-url" $VALUESFILE)

if [ ! -f license.txt ]
then
  echo license.txt not found.
  exit 1
fi

CreateProject() {

  # create project with labels required by policy
  gcloud projects create $GCP_PROJECT_ID \
    --folder=$GCP_FOLDER_ID \
    --set-as-default \
    --labels="cb-owner=devops-consultants,cb-user=$GCP_USER_LABEL,cb-environment=demo"

  # set billing account
  gcloud beta billing projects link $GCP_PROJECT_ID \
    --billing-account 013A2F-58E727-95E837

  # enable compute engine
  gcloud services enable compute.googleapis.com
}

CreateNetwork() {

  gcloud compute routers create router \
    --project=$GCP_PROJECT_ID \
    --region=$GCP_REGION \
    --network=default

  gcloud compute routers nats create internet-access \
    --router=router \
    --region=$GCP_REGION \
    --auto-allocate-nat-external-ips \
    --nat-all-subnet-ip-ranges

}

CreateVM() { # name, type, disk(GB)

  gcloud compute instances create $1 \
    --project=$GCP_PROJECT_ID \
    --zone=$GCP_ZONE \
    --machine-type=$2 \
    --network-interface=subnet=default,no-address \
    --maintenance-policy=MIGRATE \
    --no-service-account \
    --no-scopes \
    --tags=http-server,https-server \
    --create-disk=auto-delete=yes,boot=yes,image=projects/ubuntu-os-cloud/global/images/ubuntu-1804-bionic-v20211214,mode=rw,size=$3,type=projects/agrob-accelerator/zones/$GCP_ZONE/diskTypes/pd-standard \
    --reservation-affinity=any

}

RunSSH() {
  gcloud beta compute ssh --zone $GCP_ZONE $1 --tunnel-through-iap --project $GCP_PROJECT_ID -- "$2"
}

SCP() {
  gcloud beta compute scp "$1" "$2" --zone $GCP_ZONE --tunnel-through-iap --project $GCP_PROJECT_ID
}

Install() {

  RunSSH cluster-manager "sudo apt-get update && sudo apt-get install -y -qq autoconf linux-headers-\$(uname -r) && wget -O installer $INSTALLER_URL && chmod +x installer && sudo ./installer --mode silent --type cm && echo '. /opt/ecloud/i686_Linux/conf/ecloud.bash.profile' > .bashrc && sudo chown \$(id -un):\$(id -gn) .cmsession"
  SCP "license.txt" "cluster-manager:"
  RunSSH cluster-manager "cmtool login admin changeme && cmtool importLicenseData license.txt"

  RunSSH agents "sudo apt-get update && sudo apt-get install -y -qq autoconf linux-headers-\$(uname -r) libssl-dev gcc g++ make && wget -O installer $INSTALLER_URL && chmod +x installer && sudo ./installer --mode silent --type agent --agentcmhost cluster-manager"
  
  RunSSH emake-machine "sudo apt-get update && sudo apt-get install -y -qq autoconf libssl-dev gcc g++ make && wget -O installer $INSTALLER_URL && chmod +x installer && sudo ./installer --mode silent --type emake && echo 'export PATH=\$PATH:/opt/ecloud/i686_Linux/bin' > .bashrc"

}

RunDemo() {
  RunSSH emake-machine "wget https://github.com/Kitware/CMake/releases/download/v3.22.1/cmake-3.22.1.tar.gz && tar -xzvf cmake-3.22.1.tar.gz && cd cmake-3.22.1 && ./bootstrap && time emake --emake-cm=cluster-manager --emake-jobcache=all"
}


CreateProject
CreateNetwork
CreateVM emake-machine e2-standard-4 100
CreateVM cluster-manager e2-standard-2 40
CreateVM agents e2-standard-8 100
sleep 30
Install
RunDemo
