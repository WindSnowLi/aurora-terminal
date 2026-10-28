# =============================================================================
#  ~/.zshrc — MSYS2 (UCRT64) + Oh My Zsh + Powerlevel10k
#  迁移：复制 .zshrc / .p10k.zsh / fastfetch/aurora.jsonc，重开终端即可
#  配套脚本：Install-ZshEnv.ps1
# =============================================================================

# ── Oh My Zsh 基础 ───────────────────────────────────────────────────────────
export ZSH="$HOME/.oh-my-zsh"
export ZSH_CUSTOM="$ZSH/custom"

# 主题：powerlevel10k（异步 git 状态，git 仓库里也不卡）
ZSH_THEME="powerlevel10k/powerlevel10k"
# instant prompt 与启动时输出（fastfetch）互斥，默认关闭；
# 若不需要启动横幅，可设为 quiet 获得更快的冷启动
: ${POWERLEVEL9K_INSTANT_PROMPT:=off}

# 关闭自动更新提示（需要升级时手动执行 omz update）
zstyle ':omz:update' mode disabled

# ── 插件参数（必须在 oh-my-zsh.sh 之前）─────────────────────────────────────
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=60'
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20

# zsh-completions 的补全目录
fpath+=("$ZSH_CUSTOM/plugins/zsh-completions/src")

plugins=(
  git
  zsh-autosuggestions
  zsh-syntax-highlighting
  zsh-completions
  fzf
  fzf-tab
  sudo
  extract
  colored-man-pages
  cp
  web-search
)

source "$ZSH/oh-my-zsh.sh"

# ── 提示符（p10k）───────────────────────────────────────────────────────────
[[ -f "$HOME/.p10k.zsh" ]] && source "$HOME/.p10k.zsh"

# ── 历史记录 ────────────────────────────────────────────────────────────────
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt EXTENDED_HISTORY HIST_IGNORE_ALL_DUPS HIST_REDUCE_BLANKS HIST_VERIFY SHARE_HISTORY

# ── 目录跳转 ────────────────────────────────────────────────────────────────
setopt AUTO_CD AUTO_PUSHD PUSHD_IGNORE_DUPS INTERACTIVE_COMMENTS

if (( $+commands[zoxide] )); then
  eval "$(zoxide init zsh --cmd z)"
  # 修复 zoxide 在 Cygwin/MSYS 下生成的脚本缺陷：cygpath -w "\builtin pwd -L" 少写了 $( )，
  # 会把字面量当路径，导致 "zoxide: not a directory: C:\builtin pwd -L"
  function __zoxide_pwd() { \builtin pwd -L }
fi

# ── fzf（Ctrl+R 历史 / Ctrl+T 文件 / Alt+C 目录）────────────────────────────
if (( $+commands[fzf] )); then
  export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git --exclude node_modules'
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git --exclude node_modules'
  export FZF_DEFAULT_OPTS="--height 60% --layout=reverse --border rounded --info=inline --color=fg:#E5E7EB,bg:#0B0E1A,hl:#2DD4BF,fg+:#F8FAFC,bg+:#1B2036,hl+:#5EEAD4,info:#94A3B8,prompt:#A78BFA,pointer:#FB7185,marker:#34D399,spinner:#A78BFA,header:#64748B"
  export FZF_CTRL_R_OPTS='--preview "echo {}" --preview-window down:3:hidden:wrap --bind "?:toggle-preview"'
  export FZF_ALT_C_OPTS='--preview "eza --tree --level=2 --icons --color=always {} 2>/dev/null | head -40"'

  zstyle ':fzf-tab:complete:*:*' fzf-preview 'eza -1 --icons --color=always -- $realpath 2>/dev/null'
  zstyle ':fzf-tab:*' use-fzf-default-opts yes
  zstyle ':fzf-tab:*' fzf-min-height 10
fi

# ── 现代 CLI 别名 ───────────────────────────────────────────────────────────
if (( $+commands[eza] )); then
  alias ls='eza --icons --group-directories-first'
  alias l='eza -lh --icons --group-directories-first --git'
  alias ll='eza -l --icons --group-directories-first --git --header'
  alias la='eza -lah --icons --group-directories-first --git --header'
  alias lt='eza --tree --level=2 --icons --group-directories-first'
  alias tree='eza --tree --icons'
else
  alias ls='ls --color=auto'
  alias ll='ls -lh'
  alias la='ls -lah'
  alias lt='ls -R'
fi

(( $+commands[bat] )) && alias cat='bat --style=plain --paging=never'
(( $+commands[lazygit] )) && alias lg='lazygit'
(( $+commands[fastfetch] )) && alias ff='fastfetch'
alias g='git'
alias gs='git status -sb'
alias gd='git diff --stat'
alias gco='git checkout'
alias gl='git log --oneline --graph --decorate -20'

alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias reload='source ~/.zshrc'
alias p10k-reload='p10k reload'
alias myip='curl -s https://myip.ipip.net'
alias ports='netstat -ano | grep LISTENING'

# ── 启动信息（仅新终端首次，SHLVL=1；ZSH_NO_FASTFETCH=1 可跳过）─────────────
if [[ -o interactive && $SHLVL -le 1 && -z $ZSH_NO_FASTFETCH ]] && (( $+commands[fastfetch] )); then
  fastfetch --config "$HOME/.config/fastfetch/aurora.jsonc" 2>/dev/null || fastfetch
fi
