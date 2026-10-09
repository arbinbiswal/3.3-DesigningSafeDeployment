#!/bin/bash

set -e

IMAGE="${REGISTRY}/orion-api:${IMAGE_TAG}"
SERVICE_NAME="${SERVICE_NAME:-orion-api}"
DEPLOY_ENV="${DEPLOY_ENV:-production}"

echo "[deploy] Deploying $DEPLOY_ENV service $SERVICE_NAME with image: $IMAGE"
docker build -t "$IMAGE" .

echo "[deploy] Pushing to registry..."
docker push "$IMAGE"

echo "[deploy] Updating $DEPLOY_ENV service..."
gcloud run services update "$SERVICE_NAME" \
  --image "$IMAGE" \
  --region us-central1 \
  --platform managed

echo "[deploy] Done."
