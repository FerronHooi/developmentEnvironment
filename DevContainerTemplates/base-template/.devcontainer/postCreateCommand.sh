#!/bin/bash

# Post-create command script for development container
# This runs once when the container is first created

set -e

# Load environment variables from .env file if it exists
if [ -f ".devcontainer/.env" ]; then
    echo "Loading environment variables from .env file..."
    # Use grep to filter out comments and empty lines, then export
    grep -v '^#' .devcontainer/.env | grep -v '^$' | while IFS='=' read -r key value; do
        if [ -n "$key" ]; then
            # Remove quotes and whitespace
            key="${key// /}"
            value="${value#\"}"
            value="${value%\"}"
            export "$key=$value"
            echo "  Loaded: $key"
        fi
    done 2>/dev/null || echo "  Warning: Issue loading some environment variables"
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

    # Mark workspace as safe directory to avoid ownership issues
    git config --global --add safe.directory /workspace
    git config --global --add safe.directory /workspace/project
    git config --global --add safe.directory '*'

    # Configure line endings for Windows/Linux compatibility
    git config --global core.autocrlf input
    git config --global core.eol lf

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

    # Fix Git index if files appear as modified due to line ending differences
    if [ -d ".git" ]; then
        log_info "Fixing Git line ending issues..."

        # First, ensure .gitattributes exists with proper line ending settings
        if [ ! -f ".gitattributes" ]; then
            log_info "Creating .gitattributes for line ending normalization..."
            cat > .gitattributes << 'EOF'
# Auto detect text files and perform LF normalization
* text=auto eol=lf

# Specific file types
*.py text eol=lf
*.pyw text eol=lf
*.pyx text eol=lf
*.pyi text eol=lf
*.sh text eol=lf
*.bash text eol=lf
*.zsh text eol=lf
*.fish text eol=lf
*.yml text eol=lf
*.yaml text eol=lf
*.json text eol=lf
*.toml text eol=lf
*.ini text eol=lf
*.cfg text eol=lf
*.conf text eol=lf
*.js text eol=lf
*.jsx text eol=lf
*.ts text eol=lf
*.tsx text eol=lf
*.css text eol=lf
*.scss text eol=lf
*.html text eol=lf
*.xml text eol=lf
*.md text eol=lf
*.rst text eol=lf
*.txt text eol=lf
Dockerfile text eol=lf
Makefile text eol=lf
*.mk text eol=lf

# Windows specific files should keep CRLF
*.bat text eol=crlf
*.cmd text eol=crlf
*.ps1 text eol=crlf

# Binary files
*.png binary
*.jpg binary
*.jpeg binary
*.gif binary
*.ico binary
*.pdf binary
*.zip binary
*.tar binary
*.gz binary
*.7z binary
*.pyc binary
*.pyo binary
*.pyd binary
*.so binary
*.dll binary
*.exe binary
*.whl binary
EOF
        fi

        # Refresh the Git index to fix line ending issues
        log_info "Refreshing Git index to fix line ending issues..."

        # This command tells Git to re-scan the working directory for changes
        git add --renormalize . 2>/dev/null || true

        # Reset the index without touching working tree
        git reset 2>/dev/null || true

        # Update the index to match the working tree, ignoring line ending changes
        git update-index --refresh 2>/dev/null || true

        # If there are still modified files showing, it might be actual changes
        if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
            log_warning "Git shows modified files - these may be real changes or persistent line ending issues"
            log_warning "Run 'git diff' to see actual changes"
        else
            log_info "Git repository is clean"
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

# Setup MCP (Model Context Protocol) servers
setup_mcp_servers() {
    log_info "Setting up MCP servers..."

    # Ensure npm cache is available
    mkdir -p ~/.npm

    # Pre-cache commonly used MCP servers to speed up first use
    log_info "Pre-caching MCP server packages..."

    # Context7 - Up-to-date code documentation
    npx -y @upstash/context7-mcp@latest --version > /dev/null 2>&1 && \
        log_info "Context7 MCP server cached" || \
        log_warning "Failed to cache Context7 MCP server"

    # Filesystem server for file operations
    npx -y @modelcontextprotocol/server-filesystem --version > /dev/null 2>&1 && \
        log_info "Filesystem MCP server cached" || \
        log_warning "Failed to cache Filesystem MCP server"

    # Memory server for persistent storage
    npx -y @modelcontextprotocol/server-memory --version > /dev/null 2>&1 && \
        log_info "Memory MCP server cached" || \
        log_warning "Failed to cache Memory MCP server"

    # GitHub server (if token is available)
    if [ -n "${GITHUB_TOKEN}" ]; then
        npx -y @modelcontextprotocol/server-github --version > /dev/null 2>&1 && \
            log_info "GitHub MCP server cached" || \
            log_warning "Failed to cache GitHub MCP server"
    fi

    # Azure server (if credentials are available)
    if [ -n "${AZURE_TENANT_ID}" ] && [ -n "${AZURE_CLIENT_ID}" ]; then
        npx -y @modelcontextprotocol/server-azure --version > /dev/null 2>&1 && \
            log_info "Azure MCP server cached" || \
            log_warning "Failed to cache Azure MCP server"
    fi

    # Create MCP configuration directory
    mkdir -p ~/.mcp

    # Create a marker file to indicate MCP is set up
    touch ~/.mcp/.initialized

    log_info "MCP servers setup complete"
}

# Setup Codebox resources
setup_codebox() {
    log_info "Setting up Codebox resources..."

    # Check if codebox directory exists
    if [ -d "/workspace/codebox" ]; then
        log_info "Codebox met API tools beschikbaar"

        # Make Python helpers importable
        if [ -d "/workspace/codebox/api-tools/helpers" ]; then
            echo "export PYTHONPATH=/workspace/codebox/api-tools/helpers:\$PYTHONPATH" >> ~/.bashrc
            log_info "Python helpers path toegevoegd aan PYTHONPATH"
        fi

        # List available helpers
        if [ -d "/workspace/codebox/api-tools/helpers" ]; then
            helper_count=$(ls -1 /workspace/codebox/api-tools/helpers/*.py 2>/dev/null | wc -l)
            if [ "$helper_count" -gt 0 ]; then
                log_info "Gevonden: $helper_count Python helper(s)"
            fi
        fi

        # Check for API check guide
        if [ -f "/workspace/codebox/api-tools/api-check-guide.md" ]; then
            log_info "API check guide beschikbaar"
        fi
    else
        log_warning "Codebox directory niet gevonden"
    fi

    # Check for Claude slash commands
    if [ -d "/workspace/.claude/commands" ]; then
        command_count=$(ls -1 /workspace/.claude/commands/*.md 2>/dev/null | wc -l)
        if [ "$command_count" -gt 0 ]; then
            log_info "Claude slash commands gevonden: $command_count command(s)"
            log_info "Gebruik /help om alle commands te zien"
        fi
    fi
}

# Setup developmentEnvironment as submodule
setup_development_submodule() {
    log_info "Checking developmentEnvironment setup..."

    # Only run if we're NOT inside the developmentEnvironment template itself
    if [[ "$PWD" != *"developmentEnvironment"* ]] && [[ "$PWD" != *"DevContainerTemplates"* ]]; then

        # Check if we're in a git repository
        if [ -d ".git" ]; then

            # Check if submodule already exists
            if [ ! -d "developmentEnvironment" ]; then
                log_info "Adding developmentEnvironment as submodule..."

                # Add the submodule
                git submodule add https://github.com/FerronHooi/developmentEnvironment.git 2>/dev/null || {
                    log_warning "Could not add submodule - it may already be configured"
                }

                # Initialize and update submodule
                git submodule update --init --recursive 2>/dev/null || {
                    log_warning "Could not update submodule"
                }

                # Add to .gitignore if not already there
                if [ ! -f ".gitignore" ] || ! grep -q "^/developmentEnvironment/$" .gitignore 2>/dev/null; then
                    log_info "Adding developmentEnvironment to .gitignore..."
                    echo "" >> .gitignore
                    echo "# Development Environment (submodule - not tracked in project)" >> .gitignore
                    echo "/developmentEnvironment/" >> .gitignore

                    # Commit the .gitignore change
                    git add .gitignore
                    git commit -m "Add developmentEnvironment to .gitignore" 2>/dev/null || {
                        log_info "Gitignore updated (commit manually if needed)"
                    }
                fi

                log_info "developmentEnvironment submodule setup complete"
                log_info "VS Code will use: developmentEnvironment/DevContainerTemplates/base-template/.devcontainer/"
            else
                log_info "developmentEnvironment submodule already exists"
            fi
        else
            log_warning "Not in a git repository - skipping submodule setup"
            log_warning "Run 'git init' first, then rebuild container to add submodule"
        fi
    else
        log_info "Running inside developmentEnvironment template - skipping submodule setup"
    fi
}

# Main execution
main() {
    cd /workspace || exit 1

    # Detect project characteristics
    detect_project_type

    # Setup submodule first (so paths exist for other functions)
    setup_development_submodule

    # Run setup steps
    setup_git
    setup_ssh
    setup_python
    setup_node
    setup_azure_databricks
    setup_mcp_servers
    setup_codebox
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