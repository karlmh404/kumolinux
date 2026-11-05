# ~/.bash_profile: executed by bash(1) for login shells.

if [ -f ~/.bashrc ]; then
    . ~/.bashrc
fi

if [ -d "$HOME/bin" ] ; then
    PATH="$HOME/bin:$PATH"
fi

if [ -d "$HOME/.local/bin" ] ; then
    PATH="$HOME/.local/bin:$PATH"
fi

case "$TERM" in
    xterm*|rxvt*|foot*|alacritty*)
        echo -ne "\033]0;${USER}@${HOSTNAME}: ${PWD/#$HOME/~}\007"
        ;;
esac
