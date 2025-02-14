#!/bin/bash

# Define registry URL and image name
REGISTRY="192.168.145.182"
IMAGE_NAME="kargo/demo-app"

# List of versions to pull
VERSIONS=("1.0.0" "2.0.0" "3.0.0" "4.0.0" "5.0.0")

# Loop through each version and pull it
for VERSION in "${VERSIONS[@]}"; do
    FULL_IMAGE="$REGISTRY/$IMAGE_NAME:$VERSION"

    echo "Pulling image: $FULL_IMAGE"
    microk8s ctr images pull --plain-http "$FULL_IMAGE"

    if [ $? -eq 0 ]; then
        echo "Successfully pulled $FULL_IMAGE"
    else
        echo "Failed to pull $FULL_IMAGE"
        exit 1
    fi
done

echo "All images pulled successfully!"
