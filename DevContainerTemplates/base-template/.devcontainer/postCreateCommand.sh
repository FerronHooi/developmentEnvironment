#!/bin/bash

# Post-create command script for development container
# This runs once when the container is first created

set -e

# Load environment variables from .env file if it exists
if [ -f ".devcontainer/.env" ]; then
    echo "Loading environment variables from .env file..."
    set -a
    source .devcontainer/.env
    set +a
fi

echo "================================================"
echo "  Running Post-Create Setup"
echo "  Project: ${PROJECT_NAME:-$(basename $(pwd))}"
echo "================================================"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Function to detect project type
detect_project_type() {
    if [ -f "databricks.yml" ] || [ -d "databricks" ]; then
        log_info "Databricks project detected"
        export HAS_DATABRICKS=true
    fi

    if [ -f "requirements.txt" ] || [ -f "setup.py" ] || [ -f "pyproject.toml" ]; then
        log_info "Python project detected"
        export HAS_PYTHON=true
    fi

    if [ -f "package.json" ]; then
        log_info "Node.js project detected"
        export HAS_NODE=true
    fi

    if [ -f "docker-compose.yml" ] || [ -f "docker-compose.yaml" ]; then
        log_info "Docker Compose configuration detected"
        export HAS_DOCKER_COMPOSE=true
    fi
}

# Git configuration
setup_git() {
    log_info "Configuring Git..."

    # Setup credential helper
    git config --global credential.helper store

    # Set up Git user if not configured
    if [ -z "$(git config --global user.email)" ]; then
        if [ -n "${GIT_USER_EMAIL}" ]; then
            git config --global user.email "${GIT_USER_EMAIL}"
            log_info "Git email set to ${GIT_USER_EMAIL}"
        else
            log_warning "Git email not configured. Set GIT_USER_EMAIL in .env or run: git config --global user.email 'your.email@example.com'"
        fi
    fi

    if [ -z "$(git config --global user.name)" ]; then
        if [ -n "${GIT_USER_NAME}" ]; then
            git config --global user.name "${GIT_USER_NAME}"
            log_info "Git name set to ${GIT_USER_NAME}"
        else
            log_warning "Git name not configured. Set GIT_USER_NAME in .env or run: git config --global user.name 'Your Name'"
        fi
    fi
}

# Python environment setup
setup_python() {
    if [ "${HAS_PYTHON}" = "true" ]; then
        log_info "Setting up Python environment..."

        # Upgrade pip
        python -m pip install --upgrade pip --quiet

        # Install from requirements.txt
        if [ -f "requirements.txt" ]; then
            log_info "Installing requirements.txt..."
            pip install -r requirements.txt --quiet
        fi

        # Install from requirements-dev.txt
        if [ -f "requirements-dev.txt" ]; then
            log_info "Installing requirements-dev.txt..."
            pip install -r requirements-dev.txt --quiet
        fi

        # Install from setup.py
        if [ -f "setup.py" ]; then
            log_info "Installing package in development mode..."
            pip install -e . --quiet
        fi

        # Install from pyproject.toml
        if [ -f "pyproject.toml" ]; then
            if grep -q "tool.poetry" pyproject.toml; then
                log_info "Installing Poetry dependencies..."
                pip install poetry --quiet
                poetry install
            elif grep -q "build-backend" pyproject.toml; then
                log_info "Installing from pyproject.toml..."
                pip install -e . --quiet
            fi
        fi

        # Install from Pipfile
        if [ -f "Pipfile" ]; then
            log_info "Installing Pipenv dependencies..."
            pip install pipenv --quiet
            pipenv install --dev
        fi

        # Setup Jupyter kernel
        if [ "${ENABLE_JUPYTER}" = "true" ] && command -v jupyter &> /dev/null; then
            log_info "Setting up Jupyter kernel..."
            python -m ipykernel install --user --name="${PROJECT_NAME:-project}" --display-name="${PROJECT_NAME:-Project} (Python)"
        fi
    fi
}

# Node.js environment setup
setup_node() {
    if [ "${HAS_NODE}" = "true" ] && [ -f "package.json" ]; then
        log_info "Setting up Node.js environment..."

        # Detect and use appropriate package manager
        if [ -f "yarn.lock" ]; then
            log_info "Installing with Yarn..."
            yarn install
        elif [ -f "pnpm-lock.yaml" ]; then
            log_info "Installing with pnpm..."
            pnpm install
        elif [ -f "package-lock.json" ]; then
            log_info "Installing with npm ci..."
            npm ci
        else
            log_info "Installing with npm..."
            npm install
        fi
    fi
}

# Azure/Databricks configuration
setup_azure_databricks() {
    # Azure CLI setup
    if [ -n "${AZURE_TENANT_ID}" ] && [ -n "${AZURE_CLIENT_ID}" ]; then
        log_info "Azure credentials detected in environment"

        if [ -n "${AZURE_CLIENT_SECRET}" ]; then
            log_info "Logging into Azure with service principal..."
            az login --service-principal \
                -u "${AZURE_CLIENT_ID}" \
                -p "${AZURE_CLIENT_SECRET}" \
                --tenant "${AZURE_TENANT_ID}" \
                --output none 2>/dev/null && log_info "Azure login successful" || log_warning "Azure login failed"
        fi

        if [ -n "${AZURE_SUBSCRIPTION_ID}" ]; then
            az account set --subscription "${AZURE_SUBSCRIPTION_ID}" 2>/dev/null
        fi
    elif [ -d ~/.azure ]; then
        log_info "Azure configuration directory mounted"
    fi

    # Databricks CLI setup
    if [ -n "${DATABRICKS_HOST}" ] && [ -n "${DATABRICKS_TOKEN}" ]; then
        log_info "Configuring Databricks CLI..."

        # Create .databrickscfg
        cat > ~/.databrickscfg << EOF
[DEFAULT]
host = ${DATABRICKS_HOST}
token = ${DATABRICKS_TOKEN}
EOF
        chmod 600 ~/.databrickscfg
        log_info "Databricks CLI configured"

        # Test connection
        databricks workspace ls / > /dev/null 2>&1 && \
            log_info "Databricks connection successful" || \
            log_warning "Databricks connection failed - check credentials"
    elif [ -f ~/.databrickscfg ]; then
        log_info "Databricks configuration file mounted"
    elif [ "${HAS_DATABRICKS}" = "true" ]; then
        log_warning "Databricks project detected but credentials not configured"
        log_warning "Set DATABRICKS_HOST and DATABRICKS_TOKEN in .env file"
    fi
}

# SSH configuration
setup_ssh() {
    if [ -d ~/.ssh ]; then
        log_info "SSH configuration mounted"
        chmod 700 ~/.ssh 2>/dev/null || true
        chmod 600 ~/.ssh/id_* 2>/dev/null || true
        chmod 644 ~/.ssh/*.pub 2>/dev/null || true
        chmod 600 ~/.ssh/config 2>/dev/null || true
    fi
}

# VS Code workspace settings
setup_vscode_settings() {
    if [ ! -f ".vscode/settings.json" ]; then
        log_info "Creating VS Code workspace settings..."
        mkdir -p .vscode

        cat > .vscode/settings.json << 'EOF'
{
    "python.defaultInterpreterPath": "python",
    "python.terminal.activateEnvironment": true,
    "jupyter.interactiveWindow.cellMarker.default": "# COMMAND ----------",
    "files.exclude": {
        "**/__pycache__": true,
        "**/*.pyc": true,
        "**/.pytest_cache": true
    },
    "editor.formatOnSave": true,
    "editor.rulers": [80, 120]
}
EOF
    fi
}

# Create project directories
create_project_structure() {
    # Create common directories if they don't exist
    [ ! -d "logs" ] && mkdir -p logs && log_info "Created logs directory"
    [ ! -d "data" ] && mkdir -p data && log_info "Created data directory"
    [ ! -d "tests" ] && mkdir -p tests && log_info "Created tests directory"
    [ ! -d ".vscode" ] && mkdir -p .vscode && log_info "Created .vscode directory"
}

# Install additional tools based on project
install_project_tools() {
    # Install pre-commit hooks if config exists
    if [ -f ".pre-commit-config.yaml" ]; then
        log_info "Installing pre-commit hooks..."
        pre-commit install
    fi

    # Install additional Python tools if needed
    if [ "${HAS_PYTHON}" = "true" ]; then
        # Ensure common tools are available
        pip list | grep -q "black" || pip install black --quiet
        pip list | grep -q "flake8" || pip install flake8 --quiet
        pip list | grep -q "pytest" || pip install pytest --quiet
    fi
}

# Main execution
main() {
    cd /workspace || exit 1

    # Detect project characteristics
    detect_project_type

    # Run setup steps
    setup_git
    setup_ssh
    setup_python
    setup_node
    setup_azure_databricks
    create_project_structure
    setup_vscode_settings
    install_project_tools

    # Run custom setup if exists
    if [ -f ".devcontainer/custom-setup.sh" ]; then
        log_info "Running custom setup script..."
        bash .devcontainer/custom-setup.sh
    fi

    # Display summary
    echo ""
    echo "================================================"
    echo "  Post-Create Setup Complete!"
    echo "================================================"
    echo ""

    if [ "${HAS_PYTHON}" = "true" ]; then
        echo "Python: $(python --version)"
        echo "  Packages: $(pip list --format=freeze 2>/dev/null | wc -l) installed"
    fi

    if [ "${HAS_NODE}" = "true" ]; then
        echo "Node: $(node --version)"
        echo "  NPM: $(npm --version)"
    fi

    if [ -n "${DATABRICKS_HOST}" ]; then
        echo "Databricks: Configured for ${DATABRICKS_HOST}"
    fi

    echo ""
    log_info "Container is ready for development!"
    echo ""
    echo "Tip: Check .devcontainer/.env.example for additional configuration options"
}

# Run main function
main "$@"