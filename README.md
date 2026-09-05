# Production-Grade Fintech Wallet on AWS EKS

A highly available, cloud-native backend service for a fintech wallet application, fully containerized and orchestrated on **AWS Elastic Kubernetes Service (EKS)** using modern **Infrastructure as Code (IaC)** and **DevOps** tooling.

---

## Architecture & Tech Stack

- **Cloud & Infrastructure:** AWS EKS, VPC, AWS ECR, Terraform (IaC)
- **Containerization & Orchestration:** Docker, Kubernetes (`Deployments`, `LoadBalancer`, `Probes`)
- **Application:** Node.js, Express
- **Observability & Monitoring:** Kubernetes Metrics-Server, Prometheus
- **CI/CD Automation:** GitHub Actions

---

## Project Structure

```text
├── .github/workflows/    # Automated CI/CD pipeline configuration
├── Terraform/            # Infrastructure provisioning scripts (AWS EKS & VPC)
├── app.js                # Node.js Fintech Wallet backend application
├── Dockerfile            # Optimized multi-stage container build instructions
├── deployment.yaml       # Kubernetes deployment manifest (with liveness/readiness probes)
├── service.yaml          # Kubernetes LoadBalancer service manifest
└── package.json          # Node.js dependencies


#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

echo "=== Step 1: Provisioning Infrastructure with Terraform ==="
cd Terraform
terraform init
terraform apply -auto-approve

echo "=== Step 2: Configuring kubectl for EKS ==="
REGION="us-east-1"
CLUSTER_NAME="fintech-cluster"
aws eks update-kubeconfig --region $REGION --name$CLUSTER_NAME

echo "=== Step 3: Deploying Application Manifests to EKS ==="
cd ..
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml

echo "=== Deployment Completed Successfully! ==="
kubectl get pods
kubectl get services