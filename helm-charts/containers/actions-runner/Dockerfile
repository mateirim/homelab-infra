FROM summerwind/actions-runner:latest

USER root

# Install dependencies needed for downloads
RUN apt-get update && apt-get install -y \
    curl \
    unzip \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install Latest Kubectl
RUN export ARCH=$(dpkg --print-architecture) && \
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/${ARCH}/kubectl" && \
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl && \
    rm kubectl

# Install Latest Helm
RUN export ARCH=$(dpkg --print-architecture) && \
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install Latest Terraform
RUN export ARCH=$(dpkg --print-architecture) && \
    TER_VER=$(curl -s https://checkpoint-api.hashicorp.com/v1/check/terraform | grep -oE '"current_version":"[0-9.]+"' | cut -d'"' -f4) && \
    curl -LO "https://releases.hashicorp.com/terraform/${TER_VER}/terraform_${TER_VER}_linux_${ARCH}.zip" && \
    unzip terraform_${TER_VER}_linux_${ARCH}.zip && \
    install -o root -g root -m 0755 terraform /usr/local/bin/terraform && \
    rm terraform terraform_${TER_VER}_linux_${ARCH}.zip

USER runner