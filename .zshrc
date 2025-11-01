# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load.
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="robbyrussell"

# List of plugins that should be loaded.
# (git is included by default)
plugins=(
  git
  command-not-found
  extract
  zsh-history-substring-search
  zsh-syntax-highlighting
)

source "$ZSH/oh-my-zsh.sh"

# --- User Customizations Below This Line ---

# Set Micro as the default editor
export EDITOR='micro'
export VISUAL='micro'

# Auto-activate my main Python user environment when not in a venv
if [[ -z "$VIRTUAL_ENV" && -d "$HOME/.venv" ]]; then
    source "$HOME/.venv/bin/activate"
fi

# Keybindings for zsh-history-substring-search
# These cover most terminal emulators.
bindkey '^[[A' history-substring-search-up
bindkey '^[OA' history-substring-search-up
bindkey '^[[B' history-substring-search-down
bindkey '^[OB' history-substring-search-down

# Alias for easy config reload
alias zshreload="source ~/.zshrc"
