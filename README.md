<div align="center">

# AWS Cost Optimization Dashboard

**A serverless AWS FinOps dashboard for cost visibility and optimization insights.**

[Live Demo](https://d76jvyk0p329e.cloudfront.net) · [Architecture](#architecture) · [Deployment](#deployment) · [Project Structure](#project-structure)

![AWS](https://img.shields.io/badge/Cloud-AWS-232F3E?logo=amazonaws&logoColor=white)
![Terraform](https://img.shields.io/badge/IaC-Terraform-7B42BC?logo=terraform&logoColor=white)
![GitHub Actions](https://img.shields.io/badge/CI%2FCD-GitHub%20Actions-2088FF?logo=githubactions&logoColor=white)
![Python](https://img.shields.io/badge/Runtime-Python-3776AB?logo=python&logoColor=white)
![FinOps](https://img.shields.io/badge/Focus-FinOps-00A98F)
![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)
![Status](https://img.shields.io/badge/Status-Active-brightgreen)

</div>

> A Terraform-managed, serverless dashboard that collects AWS Cost Explorer and Compute Optimizer data through Lambda and presents it through a static frontend delivered by CloudFront.

<div align="center">

### [🌐 View Live Dashboard](https://d76jvyk0p329e.cloudfront.net)

</div>

---

## Overview

This project is a serverless AWS cost-optimization dashboard built to provide practical visibility into cloud spending and optimization opportunities. It combines **AWS Cost Explorer** and **AWS Compute Optimizer** data to surface forecasted spend, daily cost trends, service-level costs, EC2 rightsizing recommendations, Graviton migration candidates, and idle or over-provisioned Lambda findings — all without running a single persistent server.

The architecture is intentionally lightweight: **EventBridge Scheduler** invokes a Lambda collector once per day, the collector writes a JSON data file to **Amazon S3**, and a static frontend reads and renders that data through **Amazon CloudFront**.

This project was built to demonstrate applied FinOps automation: reading real AWS billing and optimization APIs, transforming that data, and delivering it through a fully serverless, Infrastructure-as-Code pipeline with zero-downtime CI/CD.

## See it in action

The dashboard is deployed publicly and renders live AWS account data.

### Dashboard preview

![AWS Cost Optimization Dashboard](docs/images/dashboard.jpg)

### Example results

Snapshot from a recent run — values are account- and date-specific and change as AWS billing data updates:

| Metric | Value |
|---|---|
| Forecasted spend (current month) | `$7.17` |
| Compute Optimizer status | `Active` |
| Potential monthly savings | `$0.00` (no recommendations yet available) |
| Top service-level cost category | `EC2 - Other` |
| Empty recommendation handling | Verified — no failures on empty datasets |

## Architecture

![AWS Cost Optimization Dashboard architecture](docs/images/architecture.png)

### Flow summary

- **Deployment** — GitHub Actions authenticates to AWS with OpenID Connect (OIDC) and runs Terraform without storing long-lived AWS access keys.
- **Scheduling** — Amazon EventBridge Scheduler invokes the collector Lambda once per day.
- **Collection** — Lambda queries Cost Explorer for daily cost, service-level spend, and the monthly forecast.
- **Optimization** — Lambda queries Compute Optimizer for EC2 rightsizing, Graviton, and Lambda optimization findings when available.
- **Storage** — The collector writes generated dashboard data to Amazon S3.
- **Delivery** — CloudFront serves the static dashboard and its generated data securely over HTTPS.

## Main components

| Component | Purpose |
|---|---|
| GitHub Actions | Validates and deploys infrastructure with Terraform. |
| GitHub OIDC + AWS IAM | Provides short-lived deployment credentials without static AWS keys. |
| Amazon EventBridge Scheduler | Triggers the daily collector run. |
| AWS Lambda (Python) | Collects, transforms, and writes cost-optimization data. |
| AWS Cost Explorer | Supplies daily cost, top services, and forecasted spend. |
| AWS Compute Optimizer | Supplies EC2 rightsizing, Graviton, and Lambda optimization findings. |
| Amazon S3 | Stores the static frontend and generated dashboard JSON. |
| Amazon CloudFront | Delivers the dashboard globally over HTTPS. |
| Terraform | Defines all cloud infrastructure as code, including remote state backend. |

## Features

- Current-month AWS spend forecast.
- Last 30 days of daily cost data.
- Top AWS services by cost.
- Compute Optimizer enrollment status.
- EC2 rightsizing recommendations when AWS has enough workload telemetry.
- Graviton migration candidates when available.
- Idle or over-provisioned Lambda findings.
- Safe empty states for accounts without recommendations.
- Automated daily data refresh.
- Infrastructure as Code with Terraform, including a dedicated remote state backend.
- CI/CD with GitHub Actions and AWS OIDC authentication.

## Deployment

The repository contains three Terraform stacks:

```text
infra/
├── backend/     # Remote state backend (S3 + locking) for Terraform
├── dashboard/   # S3 and CloudFront static dashboard infrastructure
└── collector/   # Lambda collector and EventBridge Scheduler infrastructure
```

On a push to `main` that changes `infra/`, `src/`, or `.github/workflows/deploy.yml`, GitHub Actions performs the following:

1. Checks out the repository.
2. Configures short-lived AWS credentials through GitHub OIDC.
3. Initializes and validates Terraform.
4. Plans and applies the dashboard stack.
5. Retrieves the dashboard bucket name as a Terraform output.
6. Plans and applies the collector stack with that bucket name.

The workflow needs only these GitHub permissions:

```yaml
permissions:
  id-token: write
  contents: read
```

## Local deployment

### Prerequisites

- Terraform 1.9.5 or a compatible release.
- AWS CLI configured with permissions for the required resources.
- AWS Cost Explorer enabled in the target account.
- AWS Compute Optimizer enabled to receive optimization recommendations.

### Deploy the backend (remote state)

```bash
cd infra/backend
terraform init
terraform apply
```

### Deploy the dashboard

```bash
cd ../dashboard
terraform init
terraform validate
terraform plan
terraform apply
```

### Deploy the collector

Use the dashboard bucket name returned by the previous stack:

```bash
cd ../collector
terraform init
terraform validate
terraform plan -var="dashboard_bucket_name=<your-dashboard-bucket-name>"
terraform apply -var="dashboard_bucket_name=<your-dashboard-bucket-name>"
```

## Project structure

```text
.
├── .github/
│   └── workflows/
│       └── deploy.yml              # OIDC-based deployment workflow
├── docs/
│   └── images/
│       ├── architecture.png        # Architecture diagram
│       └── dashboard.jpg           # Dashboard preview
├── infra/
│   ├── backend/                    # Terraform remote state backend
│   ├── dashboard/                  # S3 and CloudFront Terraform stack
│   └── collector/                  # Lambda and EventBridge Terraform stack
├── src/
│   ├── dashboard/                  # Static frontend assets
│   └── collector/                  # Lambda collector code (Python)
├── .gitignore
├── LICENSE
└── README.md
```

## Validation and notes

The deployed dashboard has been validated using real AWS account data: Cost Explorer data is displayed, a monthly forecast renders successfully, service-level costs appear in the dashboard, and Compute Optimizer reports an `Active` status.

Compute Optimizer may not return rightsizing or Graviton recommendations immediately. It needs enough sustained workload metrics to generate findings, so no recommendations is an expected result for new, low-traffic, or lightly used environments.

## Cost considerations

The design keeps operational overhead low:

- The frontend is static and delivered from S3 through CloudFront.
- The collector executes once per day.
- Lambda execution is short-lived.
- The generated JSON data is small.

Actual charges depend on account usage and AWS service pricing, including Cost Explorer, CloudFront, S3, Lambda, and any resources being monitored. Configure AWS Budgets and billing alerts before using this in a production environment.

## Technologies

**Cloud & Infrastructure:** AWS S3 · Amazon CloudFront · AWS Lambda · Amazon EventBridge Scheduler · AWS Cost Explorer · AWS Compute Optimizer · AWS IAM

**IaC & CI/CD:** Terraform · GitHub Actions · GitHub OIDC

**Application:** Python (collector) · HTML, CSS, JavaScript (frontend)

## Related project

This project complements my [Cloud Resume Challenge + AI (Bedrock)](https://github.com/tatan461/cloud-resume-challenge).

Together, these two projects demonstrate:

- Serverless AWS architecture designed for low operational overhead.
- Infrastructure as Code with Terraform across multiple independent stacks.
- OIDC-based CI/CD with no long-lived cloud credentials.
- Practical cloud operations spanning user-facing applications and FinOps automation.

## Author

**Jonathan Angel Gonzalez** ([@tatan461](https://github.com/tatan461))

## License

This project is licensed under the [MIT License](LICENSE).
