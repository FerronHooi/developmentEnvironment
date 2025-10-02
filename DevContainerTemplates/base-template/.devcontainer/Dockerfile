# Multi-stage Dockerfile for comprehensive development environment
# Supports Python, Node.js, Azure, Databricks, and various data tools

ARG PYTHON_VERSION=3.11
ARG NODE_VERSION=18
ARG VARIANT=bullseye

# Base stage with Python
FROM python:${PYTHON_VERSION}-${VARIANT} AS base

# Avoid warnings by switching to noninteractive
ENV DEBIAN_FRONTEND=noninteractive

# Install essential system packages
RUN apt-get update && apt-get install -y \
    # Build essentials
    build-essential \
    gcc \
    g++ \
    make \
    cmake \
    # Development tools
    git \
    git-lfs \
    vim \
    nano \
    less \
    curl \
    wget \
    jq \
    zip \
    unzip \
    # System libraries
    libssl-dev \
    libffi-dev \
    libpq-dev \
    libsqlite3-dev \
    # Additional utilities
    htop \
    tree \
    ripgrep \
    fd-find \
    bat \
    ncdu \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    sudo \
    locales \
    # Network tools
    iputils-ping \
    net-tools \
    dnsutils \
    telnet \
    # Process management
    supervisor \
    && rm -rf /var/lib/apt/lists/*

# Set locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# Install Node.js and npm
ARG NODE_VERSION
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Install global Node.js packages
RUN npm install -g \
    yarn \
    pnpm \
    typescript \
    ts-node \
    nodemon \
    pm2 \
    prettier \
    eslint \
    @angular/cli \
    @vue/cli \
    create-react-app \
    vite \
    vercel \
    netlify-cli \
    serverless

# Upgrade pip and install Python build tools
RUN python -m pip install --no-cache-dir --upgrade \
    pip \
    setuptools \
    wheel \
    build

# Install Python development packages
RUN pip install --no-cache-dir \
    # === Development Tools ===
    black \
    flake8 \
    pylint \
    mypy \
    isort \
    autopep8 \
    yapf \
    bandit \
    pytest \
    pytest-cov \
    pytest-mock \
    pytest-asyncio \
    tox \
    pre-commit \
    ipython \
    ipdb \
    pudb \
    # === Data Science Libraries ===
    numpy \
    pandas \
    matplotlib \
    seaborn \
    plotly \
    scikit-learn \
    scipy \
    statsmodels \
    # === Jupyter Ecosystem ===
    jupyter \
    jupyterlab \
    notebook \
    ipykernel \
    ipywidgets \
    nbconvert \
    nbformat \
    # === Web Frameworks ===
    django \
    flask \
    fastapi \
    uvicorn[standard] \
    gunicorn \
    streamlit \
    dash \
    # === Database Libraries ===
    sqlalchemy \
    alembic \
    psycopg2-binary \
    pymongo \
    redis \
    # === Azure & Databricks ===
    databricks-cli \
    databricks-connect \
    azure-core \
    azure-identity \
    azure-storage-blob \
    azure-keyvault-secrets \
    azure-cosmos \
    # === API & Async ===
    requests \
    httpx \
    aiohttp \
    asyncio \
    # === Utilities ===
    python-dotenv \
    pyyaml \
    click \
    rich \
    tqdm \
    python-dateutil \
    pytz

# Install Azure CLI
RUN curl -sL https://aka.ms/InstallAzureCLIDeb | bash

# Install Docker CLI (for Docker-in-Docker support)
RUN curl -fsSL https://download.docker.com/linux/debian/gpg | \
    gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
    https://download.docker.com/linux/debian $(lsb_release -cs) stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    apt-get update && \
    apt-get install -y docker-ce-cli docker-compose-plugin && \
    rm -rf /var/lib/apt/lists/*

# Install kubectl
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl && \
    rm kubectl

# Install Helm
RUN curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install Terraform
RUN wget -O- https://apt.releases.hashicorp.com/gpg | \
    gpg --dearmor | \
    tee /usr/share/keyrings/hashicorp-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
    https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
    tee /etc/apt/sources.list.d/hashicorp.list && \
    apt-get update && apt-get install -y terraform && \
    rm -rf /var/lib/apt/lists/*

# Install PowerShell Core
RUN wget -q "https://packages.microsoft.com/config/debian/$(lsb_release -rs)/packages-microsoft-prod.deb" && \
    dpkg -i packages-microsoft-prod.deb && \
    apt-get update && \
    apt-get install -y powershell && \
    rm packages-microsoft-prod.deb && \
    rm -rf /var/lib/apt/lists/*

# Install GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | \
    dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg && \
    chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] \
    https://cli.github.com/packages stable main" | \
    tee /etc/apt/sources.list.d/github-cli.list > /dev/null && \
    apt-get update && \
    apt-get install -y gh && \
    rm -rf /var/lib/apt/lists/*

# Create non-root user
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN groupadd --gid $USER_GID $USERNAME && \
    useradd --uid $USER_UID --gid $USER_GID -m $USERNAME && \
    echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME && \
    chmod 0440 /etc/sudoers.d/$USERNAME && \
    # Add user to docker group for Docker-in-Docker
    groupadd -f docker && \
    usermod -aG docker $USERNAME

# Create necessary directories
RUN mkdir -p /workspace && \
    chown -R $USERNAME:$USERNAME /workspace && \
    mkdir -p /home/$USERNAME/.vscode-server/extensions && \
    mkdir -p /home/$USERNAME/.cache/pip && \
    mkdir -p /home/$USERNAME/.npm && \
    mkdir -p /home/$USERNAME/.config && \
    mkdir -p /home/$USERNAME/.local/bin && \
    chown -R $USERNAME:$USERNAME /home/$USERNAME

# Switch to non-root user
USER $USERNAME
WORKDIR /home/$USERNAME

# Configure git defaults (will be overridden by mounted .gitconfig)
RUN git config --global init.defaultBranch main && \
    git config --global pull.rebase false && \
    git config --global fetch.prune true && \
    git config --global diff.colorMoved zebra && \
    git config --global core.editor "code --wait"

# Install Oh My Bash for better terminal experience
RUN bash -c "$(curl -fsSL https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh)" --unattended || true

# Setup bash aliases
RUN echo 'alias ll="ls -alF"' >> ~/.bashrc && \
    echo 'alias la="ls -A"' >> ~/.bashrc && \
    echo 'alias l="ls -CF"' >> ~/.bashrc && \
    echo 'alias gs="git status"' >> ~/.bashrc && \
    echo 'alias gd="git diff"' >> ~/.bashrc && \
    echo 'alias gl="git log --oneline --graph --decorate"' >> ~/.bashrc && \
    echo 'alias gp="git pull"' >> ~/.bashrc && \
    echo 'alias gpu="git push"' >> ~/.bashrc && \
    echo 'alias gco="git checkout"' >> ~/.bashrc && \
    echo 'alias gcm="git commit -m"' >> ~/.bashrc && \
    echo 'alias dc="docker-compose"' >> ~/.bashrc && \
    echo 'alias k="kubectl"' >> ~/.bashrc && \
    echo 'alias tf="terraform"' >> ~/.bashrc && \
    echo 'alias python="python3"' >> ~/.bashrc && \
    echo 'alias pip="pip3"' >> ~/.bashrc && \
    echo 'alias cls="clear"' >> ~/.bashrc

# Set environment variables
ENV PYTHONPATH=/workspace:$PYTHONPATH
ENV PATH=/home/$USERNAME/.local/bin:$PATH
ENV SHELL=/bin/bash

# Set working directory
WORKDIR /workspace

# Default command
CMD ["sleep", "infinity"]