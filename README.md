# Serverless-URL-Shortener-with-Real-Time-Analytics
A high-performance, cost-effective, and fully serverless URL shortener built on AWS using Terraform (IaC). This architecture handles redirection seamlessly and tracks click analytics in real-time.

## 🏗️ Architecture Overview

The infrastructure is 100% serverless, ensuring high availability and zero maintenance costs:
* **AWS API Gateway:** Handles incoming REST API requests (`POST /shorten` and `GET /{short_id}`).
* **AWS Lambda (Python 3.11):** Contains the core logic for generating short hashes and handling HTTP 302 redirections.
* **Amazon DynamoDB:** Stores the mapping between short IDs and long URLs while incrementing click counts atomically.

## 🚀 Features
* **Instant URL Shortening:** Generates a unique 6-character alphanumeric hash for any long URL.
* **Auto-Redirection:** Instantly redirects users to the original long destination upon clicking the short link.
* **Real-Time Analytics:** Tracks the number of clicks per link inside DynamoDB using atomic counters.
* **Infrastructure as Code (IaC):** Entire setup is provisioned smoothly via Terraform.

## 🛠️ Deployment Instructions

1. Clone the repository.
2. Run `terraform init` to initialize providers.
3. Run `terraform apply -auto-approve` to deploy to AWS.
4. Use the generated `api_url` output to start shortening URLs!
