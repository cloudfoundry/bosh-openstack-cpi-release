#!/bin/bash

set -e

DOCKER_IMAGE=${DOCKER_IMAGE:-boshcpi/bosh-performance}

docker login

echo "Download latest docker image..."
docker pull $DOCKER_IMAGE

echo "Pushing latest to previous..."
docker tag $DOCKER_IMAGE $DOCKER_IMAGE:previous

echo "Building docker image..."
docker build -t $DOCKER_IMAGE .

echo "Pushing docker image to '$DOCKER_IMAGE'..."
docker push $DOCKER_IMAGE
