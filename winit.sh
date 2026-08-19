#!/bin/bash
set -euo pipefail

echo "🚀 Starting Fullstack/DevOps Ubuntu WSL Setup..."

# 1. Update system and install base dependencies
echo "📦 Installing base packages..."
sudo apt-get update
export DEBIAN_FRONTEND=noninteractive
sudo apt-get install -y \
    curl git unzip wget btop build-essential \
    libssl-dev zlib1g-dev libbz2-dev libreadline-dev \
    libsqlite3-dev libncursesw5-dev xz-utils tk-dev \
    libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev \
    zsh lsd bat fzf zoxide fd-find dbus-user-session gnupg software-properties-common

# 2. Enable Systemd in WSL (Required for Docker)
echo "⚙️ Enabling Systemd..."
if ! grep -q "systemd=true" /etc/wsl.conf 2>/dev/null; then
    echo -e "[boot]\nsystemd=true" | sudo tee -a /etc/wsl.conf
fi

# 3. Install Docker & Docker Compose
echo "🐳 Installing Docker Engine..."
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    rm get-docker.sh
    sudo usermod -aG docker $USER
fi

# 4. Install AWS CLI v2
echo "☁️ Installing AWS CLI..."
if ! command -v aws &> /dev/null; then
    curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip -q awscliv2.zip
    sudo ./aws/install
    rm -rf awscliv2.zip aws
fi

# 5. Install Terraform (Official HashiCorp Repo)
echo "🏗️ Installing Terraform..."
if ! command -v terraform &> /dev/null; then
    wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
    sudo apt-get update && sudo apt-get install -y terraform
fi

# 6. Install Lazygit and Lazydocker
echo "🖥️ Installing TUIs (Lazygit & Lazydocker)..."
# Lazygit
LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
curl -sLo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
tar xf lazygit.tar.gz lazygit
sudo install lazygit /usr/local/bin
rm lazygit.tar.gz lazygit
# Lazydocker
curl -s https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash

# 7. Install Development Toolchains (uv, nvm, pnpm)
echo "🐍 Installing Python (uv) & Node.js (nvm/pnpm)..."
# uv
if ! command -v uv &> /dev/null; then
    curl -LsSf https://astral.sh/uv/install.sh | sh
fi
# nvm
if [ ! -d "$HOME/.nvm" ]; then
    export NVM_DIR="$HOME/.nvm"
    curl -so- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
    \. "$NVM_DIR/nvm.sh"
    
    # Install LTS Node and enable pnpm securely via corepack
    nvm install --lts
    corepack enable pnpm
fi

# 8. Zsh, Oh My Zsh, and UI Configuration
echo "🐚 Setting up Zsh environment..."
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    RUNZSH=no CHSH=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
    git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
    
    # Force Zsh as default shell non-interactively
    sudo usermod -s $(which zsh) $USER
fi

# Download your pre-configured Powerlevel10k settings
curl -sLo ~/.p10k.zsh https://raw.githubusercontent.com/ahmdthr/init/refs/heads/main/.p10k.zsh

echo "📝 Writing .zshrc..."
cat << 'EOF' > ~/.zshrc
# Enable Powerlevel10k instant prompt
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"
plugins=(git zsh-autosuggestions zsh-syntax-highlighting fzf)
source $ZSH/oh-my-zsh.sh

# Load Powerlevel10k config
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Toolchain initializations
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Ensure local binaries (like uv tools) are executable
export PATH="$HOME/.local/bin:$PATH"

# Modern CLI Aliases
alias ls='lsd'
alias l='ls -l'
alias la='ls -a'
alias lla='ls -la'
alias lt='ls --tree'
alias cat='batcat'
alias fd='fdfind'

# Custom Functions
# Create Project and Activate (cpa)
cpa() {
    # Check if user provided 0 or more than 2 arguments
    if [[ "$#" -eq 0 || "$#" -gt 2 ]]; then
        echo "Usage: cpa <project_name> [python_version]"
        echo "Example: cpa my_api 3.14"
        echo "Example: cpa my_api        (uses uv default)"
        return 1
    fi
   
    # 1. Create the directory and enter it
    mkdir -p "$1"
    cd "$1" || return 1
   
    # 2. Create the virtual environment
    if [ "$#" -eq 2 ]; then
        uv venv --python "$2"
    else
        uv venv
    fi
   
    # 3. Activate the environment
    source .venv/bin/activate
    echo "✅ Project $1 is ready!"
}

cra() {
    if [ "$#" -ne 1 ]; then
        echo "Usage: cpr <project_name>"
        echo "Example: cpr my_react_app"
        return 1
    fi
   
    # 1. Scaffold the project using Vite (React + TypeScript)
    pnpm create vite "$1" --template react-ts
   
    # 2. Enter the directory
    cd "$1" || return 1
   
    # 3. Install dependencies using pnpm's global store
    pnpm install
   
    # 4. Initialize a fresh Git repository
    git init
   
    echo "✅ Project $1 is ready! Run 'pnpm dev' to start the development server."
}

eval "$(zoxide init zsh)"
EOF

echo "✅ Setup Complete!"
echo "⚠️ IMPORTANT: Run 'wsl --shutdown' in Windows PowerShell to reboot systemd and start Docker, then open this Ubuntu terminal again."