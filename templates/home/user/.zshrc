# ~/.zshrc — framework-free zsh (no oh-my-zsh, no zinit, no zplug).
# Templated by 50-shell — edit templates/home/user/.zshrc, not this file.

# --- environment ---
export EDITOR="${EDITOR:-nvim}"
command -v code >/dev/null 2>&1 && export VISUAL="code --wait"
export PAGER=less
export LESS='-FRXi'
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"

# --- PATH ---
typeset -U PATH path
path=(
    "$HOME/.local/bin"
    "$HOME/.local/share/mise/shims"
    "/usr/local/bin"
    $path
)
export PATH

# --- history ---
HISTSIZE=100000
SAVEHIST=100000
HISTFILE="$XDG_CACHE_HOME/zsh/history"
[[ -d "${HISTFILE:h}" ]] || mkdir -p "${HISTFILE:h}"
setopt HIST_IGNORE_ALL_DUPS HIST_FIND_NO_DUPS HIST_IGNORE_SPACE
setopt HIST_VERIFY HIST_REDUCE_BLANKS EXTENDED_HISTORY SHARE_HISTORY

# --- shell options ---
setopt AUTO_CD CD_SILENT INTERACTIVE_COMMENTS NO_BEEP PROMPT_SUBST
setopt AUTO_PUSHD PUSHD_IGNORE_DUPS PUSHD_SILENT
bindkey -e

# --- completion ---
autoload -Uz compinit
compinit -d "$XDG_CACHE_HOME/zsh/zcompdump"
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*:descriptions' format '%F{yellow}-- %d --%f'
zstyle ':completion:*' group-name ''

# --- zsh-autosuggestions (apt: /usr/share/zsh-autosuggestions) ---
if [[ -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]]; then
    source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
    ZSH_AUTOSUGGEST_STRATEGY=(history completion)
    ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#665c54,italic'
fi

# --- fzf (Debian packages it under /usr/share/doc/fzf/examples/) ---
[[ -f /usr/share/doc/fzf/examples/key-bindings.zsh ]] \
    && source /usr/share/doc/fzf/examples/key-bindings.zsh
[[ -f /usr/share/doc/fzf/examples/completion.zsh ]] \
    && source /usr/share/doc/fzf/examples/completion.zsh
export FZF_DEFAULT_OPTS='
  --height=40% --layout=reverse --border=rounded
  --color=fg:#ebdbb2,bg:#1d2021,hl:#fabd2f
  --color=fg+:#ebdbb2,bg+:#3c3836,hl+:#fe8019
  --color=info:#83a598,prompt:#d3869b,pointer:#fe8019
  --color=marker:#b8bb26,spinner:#fe8019,header:#83a598'
export FZF_DEFAULT_COMMAND='fdfind --type=f --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND='fdfind --type=d --hidden --follow --exclude .git'

# --- mise (Node / Python / Ruby / Go) ---
command -v mise >/dev/null 2>&1 && eval "$(mise activate zsh)"

# --- Socket Firewall (sfw) — wrap pnpm to block malicious packages ---
# Installed globally under mise-managed node by 60-dev.  A function (not
# an alias) so it survives subshells.  Use `command pnpm …` as an escape
# hatch when you need to bypass sfw (e.g. local debugging).
if command -v sfw >/dev/null 2>&1; then
    pnpm() { sfw pnpm "$@"; }
fi

# --- zoxide (smart cd) ---
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init --cmd cd zsh)"

# --- aliases ---
if command -v eza >/dev/null 2>&1; then
    alias ls='eza --group-directories-first --icons=auto'
    alias ll='eza -lh --group-directories-first --icons=auto --git'
    alias la='eza -lah --group-directories-first --icons=auto --git'
    alias lt='eza -T --git-ignore --icons=auto --level=2'
fi
command -v bat >/dev/null 2>&1 && alias cat='bat --paging=never --style=plain'
command -v batcat >/dev/null 2>&1 && alias bat='batcat'
command -v fdfind >/dev/null 2>&1 && alias fd='fdfind'
command -v btop >/dev/null 2>&1 && alias top='btop'
command -v lazygit >/dev/null 2>&1 && alias lg='lazygit'
command -v lazydocker >/dev/null 2>&1 && alias ld='lazydocker'
alias gs='git status -sb'
alias gd='git diff'
alias gl='git log --oneline --graph --decorate -20'
alias gp='git pull --ff-only'
alias open='xdg-open'

# --- starship prompt ---
command -v starship >/dev/null 2>&1 && eval "$(starship init zsh)"

# --- zsh-syntax-highlighting (MUST be sourced last) ---
[[ -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] \
    && source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# --- fastfetch greeting on first interactive shell of the session ---
if [[ -o interactive && -t 1 && -z "${SER8_FASTFETCH_DONE:-}" ]]; then
    export SER8_FASTFETCH_DONE=1
    command -v fastfetch >/dev/null 2>&1 && fastfetch
fi
