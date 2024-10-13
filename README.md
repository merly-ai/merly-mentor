# Merly Mentor

## Overview

Merly Mentor is a self-supervised, federated learning system designed to reason about the semantics of code. Using an iterative, multi-tiered code abstraction model, Mentor can analyze code, learning from hundreds of billions of lines in a single day. This system is optimized to run on commodity hardware, allowing it to extract insights about code syntax, patterns, and semantics.

Mentor is capable of learning both "good" and "bad" code practices, making it a versatile tool for various development tasks. These include:
- Detecting potential technical debt or defects in code and recommending fixes.
- Grading the quality of code in a repository.
- Guiding developers through critical aspects of a codebase.

## Key Features

1. **Distributed Learning Framework**: Scales to learn from massive codebases.
2. **Defect Detection**: Identifies code smells, potential bugs, and technical debt.
3. **Code Quality Grading**: Grades repositories based on code structure, semantics, and practices.
4. **Automated Code Guidance**: Provides actionable recommendations for code improvement.

## Getting Started

To start using Merly Mentor, you will need a valid registration key. You can obtain a free 30-day trial by signing up for early access at [Merly AI Early Access](https://www.merly.ai/early-access).

### Prerequisites
- Docker installed
- Kubernetes (optional, for cluster deployment)
- Helm (optional, for Helm chart deployment)

## Installation

### Single Container Deployment with Docker

To deploy Merly Mentor using Docker:

1. Ensure that you create the necessary directory and set the required permissions:

   ```bash
   mkdir mentor-data
   sudo chown -R 999:999 mentor-data
   sudo chmod -R 755 mentor-data
   ```

2. Pull the container image and run it:

   ```bash
   docker run -d \
   --name merly-mentor \
   -e REGISTRATION_KEY=your_registration_key \
   -p 3000:3000 \
   -v ./mentor-data:/app/.mentor \
   merlyai/merly-mentor
   ```

3. Access Merly Mentor by opening your browser and navigating to `http://localhost:3000`.


### Multi-Container Deployment with Docker Compose

For a more modular deployment, use Docker Compose. Below is a sample `docker-compose.yml` file:

```yaml
services:
  merly-models:
    image: merlyai/merly-mentor-models:v2.0.0
    volumes:
      - models-data:/app/.models

  merly-assets:
    image: merlyai/merly-mentor-assets:v1.0.0
    volumes:
      - assets-data:/app/.assets

  merly-mentor:
    image: merlyai/merly-mentor-daemon:v0.4.19
    environment:
      - REGISTRATION_KEY=${REGISTRATION_KEY}
    ports:
      - "4200"
    volumes:
      - mentor-data:/merly/.mentor
      - models-data:/merly/.models
      - assets-data:/merly/.assets
    init: true
    depends_on:
      - merly-models
      - merly-assets

  merly-bridge:
    image: merlyai/merly-mentor-bridge:v0.1.0
    environment:
      - MERLY_AI_DAEMON_URL=http://merly-mentor:4200/
    ports:
      - "8080"
    depends_on:
      - merly-mentor

  merly-ui:
    image: merlyai/merly-mentor-ui:v0.1.0
    environment:
      - MERLY_AI_BRIDGE_URL=http://merly-bridge:8080
    ports:
      - "3000:3000"
    depends_on:
      - merly-bridge

volumes:
  mentor-data:
    driver: local
    driver_opts:
      type: none
      device: ${PWD}/mentor-data
      o: bind
  assets-data:
    driver: local
  models-data:
    driver: local
```

1. Before running the Docker Compose, ensure the `mentor-data` directory is created and permissions are correctly set:

   ```bash
   mkdir mentor-data
   sudo chown -R 999:999 mentor-data
   sudo chmod -R 755 mentor-data
   ```

2. Deploy the stack:

   ```bash
   docker-compose up -d
   ```

### Kubernetes Deployment

#### Using Kubernetes Manifests

1. Set your registration key and apply the manifests to deploy Merly Mentor on Kubernetes:

   ```bash
   export REGISTRATION_KEY="your_registration_key"
   curl -s https://raw.githubusercontent.com/merly-ai/merly-mentor/refs/heads/main/kubernetes/deploy.yaml | envsubst | kubectl apply -f -
   ```

#### Using Helm Charts

For a Helm-based deployment, refer to the official Helm chart repository at [https://charts.merly-mentor.ai](https://charts.merly-mentor.ai).


---

Merly Mentor is continuously evolving, with frequent updates to improve functionality and performance. Stay tuned for the latest features and enhancements!