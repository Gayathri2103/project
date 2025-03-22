#!/bin/bash
set -e  # Exit on any error

# Variables
REPO_URL="https://github.com/Gayathri2103/latesttest.git"
IMAGE_NAME="webserver_image"
CONTAINER_NAME="new-websrv"
PORT=9090
WORKSPACE="/var/lib/jenkins/workspace/projecttest1"

echo "🔄 Setting up Jenkins workspace..."

# Ensure Jenkins workspace exists
mkdir -p "$WORKSPACE"

# Navigate to Jenkins workspace
cd "$WORKSPACE" || { echo "❌ ERROR: Failed to access Jenkins workspace"; exit 1; }

# Clone or update repository
if [ -d "$WORKSPACE/.git" ]; then
    echo "🔄 Repository exists. Fetching latest changes..."
    git fetch origin
    git reset --hard origin/master
    git pull origin master || { echo "❌ ERROR: Failed to pull repository"; exit 1; }
else
    echo "📥 Cloning repository from $REPO_URL"
    git clone "$REPO_URL" "$WORKSPACE" || { echo "❌ ERROR: Failed to clone repository"; exit 1; }
fi

# Locate the Dockerfile
if [ -f "$WORKSPACE/Dockerfile" ]; then
    DOCKERFILE_PATH="$WORKSPACE/Dockerfile"
elif [ -f "$WORKSPACE/docker/Dockerfile" ]; then
    DOCKERFILE_PATH="$WORKSPACE/docker/Dockerfile"
else
    echo "❌ ERROR: Dockerfile not found in repository!"
    exit 1
fi

# Build Docker image
echo "🐳 Building Docker image..."
docker build -f "$DOCKERFILE_PATH" -t "$IMAGE_NAME" "$WORKSPACE" || { echo "❌ ERROR: Docker build failed"; exit 1; }

# Stop and remove existing container if it exists
if docker ps -a --format "{{.Names}}" | grep -q "^$CONTAINER_NAME$"; then
    echo "🛑 Stopping and removing existing container: $CONTAINER_NAME"
    docker stop "$CONTAINER_NAME" || true
    docker rm "$CONTAINER_NAME" || true
fi

# Run the new container
echo "🚀 Running new container: $CONTAINER_NAME on port $PORT"
docker run -d -p "$PORT":80 --name "$CONTAINER_NAME" "$IMAGE_NAME"

# Wait for a few seconds to let the container start
sleep 5

# Check if the container is running
if ! docker ps --format "{{.Names}}" | grep -q "^$CONTAINER_NAME$"; then
    echo "❌ ERROR: Container failed to start!"
    docker logs "$CONTAINER_NAME"  # Show logs for debugging
    exit 1
fi

# Display running containers
echo "📋 Listing running Docker containers..."
docker ps

# Test if Apache (httpd) is running inside the container
echo "🌐 Checking if Apache (httpd) is running inside the container..."
if docker exec "$CONTAINER_NAME" pgrep httpd > /dev/null; then
    echo "✅ Apache (httpd) is running successfully inside the container!"
else
    echo "❌ ERROR: Apache (httpd) is NOT running inside the container!"
    docker logs "$CONTAINER_NAME"  # Show logs for debugging
    exit 1
fi

