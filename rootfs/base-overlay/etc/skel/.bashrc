# ~/.bashrc: executed by bash(1) for non-login shells.

case $- in
    *i*) ;;
      *) return;;
esac

HISTCONTROL=ignoreboth
shopt -s histappend
HISTSIZE=1000
HISTFILESIZE=2000
shopt -s checkwinsize

if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    alias grep='grep --color=auto'
fi

alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

# KUMO PROMPT
K_C_RESET='\[\e[0m\]'
K_C_BOLD='\[\e[1m\]'
K_C_DIM='\[\e[2m\]'
K_C_USER='\[\e[96m\]'
K_C_HOST='\[\e[94m\]'
K_C_DIR='\[\e[95m\]'
K_C_BRIGHT_RED='\[\e[91m\]'
K_CLOUD='☁'
K_PROMPT_SYMBOL='❯'

if [ "$EUID" -eq 0 ]; then
    K_USER_COLOR="$K_C_BRIGHT_RED"
    K_HOST_COLOR="$K_C_BRIGHT_RED"
    K_C_DIR='\[\e[91m\]'
else
    K_USER_COLOR="$K_C_USER"
    K_HOST_COLOR="$K_C_HOST"
fi

_kumo_git_branch() {
    git rev-parse --is-inside-work-tree >/dev/null 2>&1 || return
    git symbolic-ref --quiet --short HEAD 2>/dev/null || \
    git rev-parse --short HEAD 2>/dev/null || return
}

kumo_prompt() {
    local exit_code=$?
    local exit_indicator=''
    if [ "$exit_code" -ne 0 ]; then
        exit_indicator="${K_C_BRIGHT_RED}[!$exit_code]${K_C_RESET} "
    fi
    local cwd="${PWD/#$HOME/\~}"
    local git_branch
    git_branch="$(_kumo_git_branch)"
    PS1="${exit_indicator}${K_CLOUD} ${K_USER_COLOR}\u${K_C_RESET}${K_C_DIM}@${K_C_RESET}${K_HOST_COLOR}\h${K_C_RESET} ${K_C_DIR}${cwd}${K_C_RESET}${git_branch}\n${K_PROMPT_SYMBOL} ${K_C_RESET}"
}

PROMPT_COMMAND='kumo_prompt'
