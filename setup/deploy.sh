#!/bin/bash
COLOR='\033[0;36m' # Cyan
NC='\033[0m' # No Color
# Variables
PROJECT_ID=$(gcloud config get-value project 2> /dev/null)
PROJECT_NAME=$(gcloud projects describe $PROJECT_ID --format="value(name)")
PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID | grep projectNumber | sed "s/.* '//;s/'//g")
SERVICE_ACCOUNT=$PROJECT_NUMBER-compute@developer.gserviceaccount.com
ANNOTATIONS_IMAGE_NAME="advizor-annotator"
ANNOTATIONS_DIR="annotator"
TAG="latest"


enable_apis() {
  echo -e "${COLOR}Enabling APIs...${NC}"
  gcloud services enable storage-component.googleapis.com
  gcloud services enable artifactregistry.googleapis.com \
    run.googleapis.com \
    iamcredentials.googleapis.com \
    cloudbuild.googleapis.com \
    aiplatform.googleapis.com \
    pubsub.googleapis.com \
    eventarc.googleapis.com \
    bigquery.googleapis.com \
    cloudresourcemanager.googleapis.com \
    videointelligence.googleapis.com \
    cloudscheduler.googleapis.com \
    compute.googleapis.com
}

create_image() {
    echo "Enabling container deployment..."
    gcloud auth configure-docker
    echo -e "${COLOR}Creating Image...${NC}"
    docker build -t $1 -f $2/Dockerfile $2/
    docker tag $1 gcr.io/${PROJECT_ID}/$1:${TAG}
    docker push gcr.io/${PROJECT_ID}/$1:${TAG}
    echo "Image pushed to GCP Container Registry successfully."
}

run_tf() {
    cd setup
    terraform init
    echo -e "${COLOR}Creating Infra...${NC}"
    terraform apply -var "project_id=$PROJECT_ID" -var "project_number=$PROJECT_NUMBER" -auto-approve
    echo -e "${COLOR}Infra Created!${NC}"
}

deploy_all() {
    enable_apis
    create_image "$ANNOTATIONS_IMAGE_NAME" "$ANNOTATIONS_DIR"
    run_tf
}


for i in "$@"; do
    "$i"
    exitcode=$?
    if [ $exitcode -ne 0 ]; then
        echo "Breaking script as command '$i' failed"
        exit $exitcode
    fi
done