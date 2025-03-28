# AI Workshop Provisioner

This project provides the infrastructure code (Terraform) and supporting components (Docker images, User Registration App) to deploy a complete AI/ML workshop environment on AWS Elastic Kubernetes Service (EKS).

The environment includes:
*   An EKS cluster with CPU and GPU node groups.
*   JupyterHub deployed via Helm for multi-user notebook access.
*   A custom Jupyter notebook Docker image with pre-installed AI/ML libraries (LangChain, OpenAI, Transformers, vLLM, etc.) and tools (Podman, NVIDIA toolkit).
*   A Next.js User Registration application for attendees to sign up and receive their unique workshop user ID.
*   Automated deployment and destruction using GitHub Actions.

## Features

*   **Infrastructure as Code (IaC):** Uses Terraform to define and manage all AWS resources.
*   **Scalable EKS Cluster:** Provisions an EKS cluster with autoscaling CPU and GPU node groups (`m5.xlarge`, `g5.2xlarge`).
*   **JupyterHub Environment:**
    *   Deploys JupyterHub using the official Helm chart.
    *   Uses a custom Docker image (`ghcr.io/silexdatateam/ai-workshop-provisioner/minimal-notebook-customized`) built with necessary Python libraries and tools.
    *   Supports GPU acceleration within user notebooks via the NVIDIA device plugin.
    *   Configures Dummy Authentication using a shared password.
    *   Automatically pulls workshop materials from a specified Git repository using `nbgitpuller` and an SSH deploy key.
    *   Injects necessary API keys (OpenAI, Tavily, Hugging Face) into user notebook environments.
    *   Uses AWS Load Balancer Controller for Ingress and ACM for SSL termination.
*   **User Registration System:**
    *   A simple Next.js application (`ghcr.io/silexdatateam/ai-workshop-provisioner/workshop-user-registration`) allows users to register.
    *   Login protected by a shared secret.
    *   Assigns sequential user IDs (e.g., `user1`, `user2`, ...) up to a defined limit.
    *   Stores registration details (first name, last name, email, assigned ID, timestamp) in a CSV file *within the application container*.
    *   Deployed with its own Ingress and domain.
*   **Automation:**
    *   GitHub Actions workflows for building and publishing Docker images to GitHub Container Registry (GHCR).
    *   GitHub Actions workflows for deploying and destroying the entire environment via Terraform.
    *   Dependabot configured for dependency updates across Terraform, Docker, Python, NPM, and GitHub Actions.

## Architecture Overview

1.  **GitHub Actions (Deployment Workflow):** Triggered manually, assumes an AWS role via OIDC.
2.  **Terraform:** Reads configuration and variables, authenticates to AWS.
3.  **Terraform (`eks` module):** Provisions the core EKS cluster, node groups, IAM roles, OIDC provider, and necessary EKS add-ons (like EBS CSI Driver).
4.  **Terraform (`eks-config` module):**
    *   Configures Kubernetes provider to interact with the created EKS cluster.
    *   Deploys required Kubernetes components via Helm (AWS Load Balancer Controller, Cluster Autoscaler, NVIDIA Device Plugin).
    *   Creates ACM Certificates and Route53 DNS records for JupyterHub and the Registration App domains.
    *   Deploys JupyterHub via Helm using custom values (authentication, user image, GPU settings, Git repo, API keys).
    *   Deploys the User Registration App (Kubernetes Deployment, Service, Ingress).
5.  **Docker Images:** Built and pushed to GHCR via separate GitHub Actions workflows.
    *   `minimal-notebook-customized`: Used by JupyterHub user pods.
    *   `workshop-user-registration`: Used by the registration application deployment.
6.  **User Access:**
    *   Users access the registration app URL, log in with the shared secret, register, and receive their `userId`.
    *   Users access the JupyterHub URL, log in with their assigned `userId` and the shared password.

## Components

*   **`terraform/`**: Contains all Terraform code.
    *   `eks/`: Module for EKS cluster creation.
    *   `eks-config/`: Module for EKS cluster configuration (Helm charts, K8s resources).
    *   `ai-workshop.tf`: Root module tying `eks` and `eks-config` together.
    *   `variables.tf`: Defines input variables (secrets, configuration).
    *   `provider.tf`: Configures Terraform providers (AWS, Kubernetes, Helm, TLS) and S3 backend.
*   **`docker/`**: Contains the Dockerfile and configuration for the custom Jupyter notebook image.
*   **`workshop-user-registration/`**: Contains the source code and Dockerfile for the Next.js user registration application.
*   **`.github/`**:
    *   `workflows/`: GitHub Actions workflows for deployment, destruction, and image publishing.
    *   `dependabot.yml`: Dependabot configuration.

## Prerequisites

1.  **AWS Account:** An AWS account with sufficient permissions to create EKS clusters, IAM roles, EC2 instances, ALBs, Route53 records, ACM certificates, etc.
2.  **AWS OIDC Provider for GitHub Actions:** Configured in your AWS account to allow GitHub Actions workflows to assume an IAM role. See [AWS Docs](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html) and [GitHub Docs](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services).
3.  **IAM Role for GitHub Actions:** An IAM role that the GitHub Actions workflow can assume (`AWS_ROLE_TO_ASSUME`). This role needs permissions to manage the resources defined in the Terraform code.
4.  **Route 53 Public Hosted Zone:** An existing public hosted zone in Route 53 (`AI_WORKSHOP_ROUTE53_ZONE_NAME`).
5.  **GitHub Repository Secrets and Variables:** Configure the following in your GitHub repository settings (`Settings > Secrets and variables > Actions`):
    *   **Secrets:**
        *   `AWS_ROLE_TO_ASSUME`: The ARN of the IAM role GitHub Actions will assume.
        *   `SSH_PRIVATE_KEY`: SSH private key for the deploy key used to clone the workshop materials repository.
        *   `AI_WORKSHOP_SHARED_PASSWORD`: The password users will use for both the registration app login and JupyterHub login.
        *   `AWS_ADMINISTRATOR_ROLE_ARN`: ARN of an IAM Role (e.g., an admin user's role) to grant EKS ClusterAdmin access via the AWS console/CLI.
        *   `AI_WORKSHOP_DOCKER_REGISTRY_USERNAME`: Your GitHub username (or a bot account) for authenticating to GHCR.
        *   `AI_WORKSHOP_DOCKER_REGISTRY_PASSWORD`: A GitHub Personal Access Token (PAT) with `read:packages` and `write:packages` scopes.
        *   `OPENAI_API_KEY`: OpenAI API Key.
        *   `TAVILY_API_KEY`: Tavily Search API Key.
        *   `HF_TOKEN`: Hugging Face API Token (read access).
    *   **Variables:**
        *   `AWS_REGION`: The AWS region for deployment (e.g., `us-east-1`).
        *   `AI_WORKSHOP_EKS_CLUSTER_NAME`: A unique name for the EKS cluster (e.g., `my-ai-workshop`).
        *   `AI_WORKSHOP_EKS_SUBNETS`: A comma-separated list of subnet IDs for the EKS cluster (e.g., `"subnet-xxxxxxxxxxxxxxxxx,subnet-yyyyyyyyyyyyyyyyy"`). Must be in the specified `AWS_REGION`. *Ensure these subnets have appropriate tags for Load Balancer auto-discovery if needed (e.g., `kubernetes.io/cluster/<cluster-name>: shared` and `kubernetes.io/role/elb: 1`)*.
        *   `AI_WORKSHOP_DOMAIN_NAME`: The desired domain name for JupyterHub (e.g., `jupyter.myworkshop.com`).
        *   `AI_WORKSHOP_ROUTE53_ZONE_NAME`: The name of your existing Route 53 hosted zone (e.g., `myworkshop.com`). The `AI_WORKSHOP_DOMAIN_NAME` must be a subdomain of this zone. The registration app will be hosted at `ai-workshop-registration.<AI_WORKSHOP_ROUTE53_ZONE_NAME>`.
        *   `AI_WORKSHOP_MATERIALS_GIT_REPO_URL`: The SSH URL of the Git repository containing the workshop materials (e.g., `git@github.com:YourOrg/ai-workshop-materials.git`). Ensure the `SSH_PRIVATE_KEY` secret corresponds to a deploy key with read access to this repository.
        *   `NUMBER_OF_USERS`: The maximum number of users allowed to register (defaults to 30). This also influences the max size of the GPU node group.
6.  **Terraform CLI (Optional):** For local planning or debugging (`terraform plan`).
7.  **AWS CLI (Optional):** For interacting with AWS resources outside of Terraform.
8.  **kubectl & Helm (Optional):** For interacting with the EKS cluster after deployment.

## Deployment

1.  **Ensure Prerequisites:** Verify all prerequisites listed above are met, especially the GitHub secrets and variables.
2.  **Trigger Docker Image Builds (if necessary):** The `notebook-image-publish.yml` and `workshop-user-registration-image-publish.yml` workflows run automatically on changes to their respective directories (`docker/`, `workshop-user-registration/`). If you haven't made changes, you might want to run them manually once (`Actions` tab -> Select workflow -> `Run workflow`) to ensure the images exist in GHCR.
3.  **Trigger Deployment Workflow:**
    *   Navigate to the `Actions` tab in your GitHub repository.
    *   Select the `Deploy (dlewis-lab)` workflow (or your environment's equivalent name if customized).
    *   Click `Run workflow`.
    *   Choose the branch (usually `main`) and click `Run workflow`.
4.  **Monitor Workflow:** Observe the workflow progress in the Actions tab. Terraform will initialize, plan, and apply the changes in two stages: first the EKS cluster (`ai_workshop_eks_cluster`), then the EKS configuration (`ai_workshop_config`). This can take 20-30 minutes or more, especially the EKS cluster creation.

## Accessing the Workshop

1.  **Registration:**
    *   Navigate to `https://ai-workshop-registration.<AI_WORKSHOP_ROUTE53_ZONE_NAME>` (replace with your configured zone name).
    *   Log in using the `AI_WORKSHOP_SHARED_PASSWORD`.
    *   Fill in your First Name, Last Name, and Email.
    *   Click Register.
    *   On the success page, note your assigned **`userId`** (e.g., `user42`).
2.  **JupyterHub:**
    *   Navigate to `https://<AI_WORKSHOP_DOMAIN_NAME>` (replace with your configured domain).
    *   Enter your assigned **`userId`** as the username.
    *   Enter the `AI_WORKSHOP_SHARED_PASSWORD` as the password.
    *   Click Sign in.
    *   On the spawner options page, select the desired profile (e.g., "GPU Server").
    *   Click Start. Your JupyterLab environment will launch, potentially taking a few minutes if a new GPU node needs to start.
    *   The workshop materials will be available in the `ai-workshop-materials` directory in your JupyterLab file browser.

## Destroying the Environment

**Warning:** This will permanently delete all AWS resources created by Terraform, including the EKS cluster, node groups, load balancers, DNS records, and ACM certificates. User data within JupyterHub pods will be lost.

1.  **Trigger Destruction Workflow:**
    *   Navigate to the `Actions` tab in your GitHub repository.
    *   Select the `Destroy (dlewis-lab)` workflow (or your environment's equivalent).
    *   Click `Run workflow`.
    *   Choose the branch (usually `main`) and click `Run workflow`.
2.  **Monitor Workflow:** The workflow will run `terraform destroy` in reverse order, first removing the EKS configuration (`ai_workshop_config`), then the EKS cluster (`ai_workshop_eks_cluster`). This process can also take a significant amount of time.

## Configuration Details

Terraform variables are defined in `terraform/variables.tf`. Sensitive values are expected to be passed via environment variables (`TF_VAR_...`) sourced from GitHub Actions secrets during the workflow execution. Key variables include:

*   `ai_workshop_eks_cluster_name`: Name of the EKS cluster.
*   `ai_workshop_eks_subnets`: List of subnet IDs for EKS.
*   `ai_workshop_domain_name`: Domain for JupyterHub.
*   `ai_workshop_route53_zone_name`: Existing Route 53 zone.
*   `ai_workshop_materials_git_repo_url`: SSH URL for workshop content repo.
*   `number_of_users`: Max users for registration and GPU node scaling.
*   `aws_administrator_role_arn`: IAM role ARN for EKS admin access.
*   **(Secrets passed via TF_VAR_...):** `ssh_private_key`, `ai_workshop_shared_password`, `ai_workshop_docker_registry_username`, `ai_workshop_docker_registry_password`, `openai_api_key`, `tavily_api_key`, `hf_token`.

---

*Modify variable names, workflow names (`dlewis-lab`), and specific resource details as needed for your environment.*
