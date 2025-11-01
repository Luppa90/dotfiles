#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Configuration & Helpers ---

# Define color codes for pretty printing
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RESET="\033[0m"

# Get the directory where the script is located to find other repo files
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Helper function for logging info messages
info() {
  echo -e "${GREEN}[INFO]${RESET} $1"
}

# --- Main Functions ---

system_prep() {
  info "Starting system preparation..."
  sudo apt-get update
  sudo apt-get upgrade -y
  info "Installing core dependencies (git, curl, build-essential)..."
  sudo apt-get install -y git curl build-essential ca-certificates
}

setup_time_sync() {
  info "Ensuring system time is synchronized..."
  sudo apt-get install -y systemd-timesyncd
  sudo systemctl enable --now systemd-timesyncd
  info "Time synchronization service (systemd-timesyncd) is active."
}

install_terminal_tools() {
  info "Installing terminal tools (Zsh, Tmux, Micro)..."
  if ! command -v zsh &> /dev/null; then
    sudo apt-get install -y zsh
  else
    echo -e "  -> ${YELLOW}Zsh is already installed. Skipping.${RESET}"
  fi
  if ! command -v tmux &> /dev/null; then
    sudo apt-get install -y tmux
  else
    echo -e "  -> ${YELLOW}Tmux is already installed. Skipping.${RESET}"
  fi
  if ! command -v micro &> /dev/null; then
    curl https://getmic.ro | bash
    sudo mv micro /usr/local/bin/
  else
    echo -e "  -> ${YELLOW}Micro is already installed. Skipping.${RESET}"
  fi
}

install_docker() {
  info "Installing Docker and Docker Compose..."
  if ! command -v docker &> /dev/null; then
    echo "  -> Setting up Docker's APT repository..."
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    info "Adding current user to the 'docker' group..."
    sudo usermod -aG docker "$USER"
  else
    echo -e "  -> ${YELLOW}Docker is already installed. Skipping.${RESET}"
  fi
}

install_github_cli() {
  info "Installing GitHub CLI (gh)..."
  if ! command -v gh &> /dev/null; then
    echo "  -> Setting up GitHub CLI's APT repository..."
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    sudo apt-get update
    sudo apt-get install -y gh
  else
    echo -e "  -> ${YELLOW}GitHub CLI is already installed. Skipping.${RESET}"
  fi
}

setup_zsh() {
  info "Setting up Zsh and Oh My Zsh..."
  if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "  -> Installing Oh My Zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
  else
    echo -e "  -> ${YELLOW}Oh My Zsh is already installed. Skipping.${RESET}"
  fi
  local plugin_path
  plugin_path="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-history-substring-search"
  if [ ! -d "$plugin_path" ]; then
    echo "  -> Installing zsh-history-substring-search plugin..."
    git clone https://github.com/zsh-users/zsh-history-substring-search.git "$plugin_path"
  else
    echo -e "  -> ${YELLOW}zsh-history-substring-search plugin is already installed. Skipping.${RESET}"
  fi
  plugin_path="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting"
  if [ ! -d "$plugin_path" ]; then
    echo "  -> Installing zsh-syntax-highlighting plugin..."
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$plugin_path"
  else
    echo -e "  -> ${YELLOW}zsh-syntax-highlighting plugin is already installed. Skipping.${RESET}"
  fi
}

setup_tmux() {
  info "Setting up Tmux Plugin Manager (TPM)..."
  local tpm_path="$HOME/.tmux/plugins/tpm"
  if [ ! -d "$tpm_path" ]; then
    echo "  -> Installing TPM..."
    git clone https://github.com/tmux-plugins/tpm "$tpm_path"
  else
    echo -e "  -> ${YELLOW}TPM is already installed. Skipping.${RESET}"
  fi
}

# Final corrected function
install_tmux_plugins() {  
    info "Installing Tmux plugins..."
    
    # Verify .tmux.conf exists before proceeding
    if [ ! -f "$HOME/.tmux.conf" ]; then
        echo -e "  -> ${YELLOW}.tmux.conf not found. Skipping plugin installation.${RESET}"
        return
    fi
    
    # Create a temporary detached session to load the config
    # This ensures TPM environment variables are set correctly
    tmux new-session -d -s temp_setup
    
    # Give tmux a moment to initialize
    sleep 1
    
    # Now execute the installer within the tmux context
    tmux run-shell "$HOME/.tmux/plugins/tpm/bin/install_plugins"
    
    # Wait for installation to complete
    sleep 2
    
    # Clean up: kill the temporary session
    tmux kill-session -t temp_setup 2>/dev/null || true
}

setup_python() {
  info "Setting up Python environment..."
  sudo apt-get install -y python3-pip python3-venv
  if [ ! -d "$HOME/.venv" ]; then
    echo "  -> Creating global Python virtual environment in ~/.venv..."
    python3 -m venv "$HOME/.venv"
  else
    echo -e "  -> ${YELLOW}Global virtual environment ~/.venv already exists. Skipping creation.${RESET}"
  fi
  local req_file="$SCRIPT_DIR/requirements.txt"
  if [ -f "$req_file" ]; then
    echo "  -> Installing Python packages from requirements.txt..."
    "$HOME/.venv/bin/pip" install --upgrade pip
    "$HOME/.venv/bin/pip" install -r "$req_file"
  else
    echo -e "  -> ${YELLOW}requirements.txt not found. Skipping Pip package installation.${RESET}"
  fi
}

deploy_dotfiles() {
  info "Deploying dotfiles from repository..."
  local dotfiles=(".zshrc" ".tmux.conf")
  for file in "${dotfiles[@]}"; do
    local source_file="$SCRIPT_DIR/$file"
    local dest_file="$HOME/$file"
    if [ -f "$source_file" ]; then
      echo "  -> Processing $file..."
      if [ -L "$dest_file" ] || [ -f "$dest_file" ]; then
        echo "     - Backing up existing $file to ${file}.bak"
        mv "$dest_file" "${dest_file}.bak"
      fi
      echo "     - Creating symlink for $file"
      ln -s "$source_file" "$dest_file"
    else
      echo -e "  -> ${YELLOW}Source file $source_file not found. Skipping.${RESET}"
    fi
  done
}

# --- Script Execution ---

main() {
  info "Starting new server setup..."
  
  system_prep
  setup_time_sync
  install_terminal_tools
  install_docker
  install_github_cli
  setup_zsh
  setup_tmux
  setup_python
  
  deploy_dotfiles

  install_tmux_plugins

  info "Automated setup complete. The following requires manual interaction."
  echo -e "${YELLOW}--> Please follow the prompts to log in to GitHub CLI...${RESET}"
  gh auth login
  
  echo -e "${YELLOW}--> Please follow the prompts to log in to Docker...${RESET}"
  docker login

  info "Setting Zsh as the default shell..."
  sudo chsh -s "$(which zsh)" "$USER"
  
  info "${GREEN}Setup is complete!${RESET}"
  echo -e "${YELLOW}Please log out and log back in for all changes to take full effect.${RESET}"
}

main