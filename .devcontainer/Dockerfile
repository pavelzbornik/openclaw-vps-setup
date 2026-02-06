FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

# Avoid prompts from apt
ENV DEBIAN_FRONTEND=noninteractive

# Install base packages
RUN apt-get update && apt-get install -y \
    # System tools
    curl \
    wget \
    git \
    vim \
    nano \
    htop \
    tree \
    jq \
    # Python and development
    python3 \
    python3-pip \
    python3-venv \
    python-is-python3 \
    # Build tools
    build-essential \
    # Networking tools
    openssh-client \
    sshpass \
    # Other utilities
    ca-certificates \
    gnupg \
    lsb-release \
    software-properties-common \
    && rm -rf /var/lib/apt/lists/*

# Install Ansible and related tools
RUN add-apt-repository --yes --update ppa:ansible/ansible && \
    apt-get update && \
    apt-get install -y ansible && \
    rm -rf /var/lib/apt/lists/*

# Install Python packages for Ansible and testing
RUN pip3 install --no-cache-dir --break-system-packages \
    ansible-core \
    ansible-lint \
    molecule \
    molecule-plugins[docker] \
    yamllint \
    jmespath \
    docker \
    pytest \
    pytest-testinfra

# Install Docker Compose
RUN curl -fsSL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 \
    -o /usr/local/bin/docker-compose && \
    chmod +x /usr/local/bin/docker-compose

# Create SSH directory for vscode user
RUN mkdir -p /home/vscode/.ssh && \
    ssh-keygen -t ed25519 -f /home/vscode/.ssh/id_ed25519 -N "" -C "devcontainer-ansible" && \
    chown -R vscode:vscode /home/vscode/.ssh && \
    chmod 700 /home/vscode/.ssh && \
    chmod 600 /home/vscode/.ssh/id_ed25519 && \
    chmod 644 /home/vscode/.ssh/id_ed25519.pub && \
    mkdir -p /home/vscode/.cache && \
    chown -R vscode:vscode /home/vscode/.cache && \
    chmod 755 /home/vscode/.cache

# Set up ansible configuration
RUN mkdir -p /home/vscode/.ansible && \
    chown -R vscode:vscode /home/vscode/.ansible

# Install ansible-galaxy collections
COPY requirements.yml /tmp/requirements.yml
RUN ansible-galaxy collection install -r /tmp/requirements.yml && \
    rm /tmp/requirements.yml

# Clean up
ENV DEBIAN_FRONTEND=dialog

# Set working directory
WORKDIR /workspace

# Default command
CMD ["sleep", "infinity"]
