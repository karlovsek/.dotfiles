[[ -o interactive ]] && stty -ixon # Allows to use Ctrl+S
# For bash add [ "$PS1" ] && stty -ixon

if [ -e ~/.nix-profile/etc/profile.d/nix.sh ]; then . ~/.nix-profile/etc/profile.d/nix.sh; fi

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Path to your oh-my-zsh installation.
export ZSH=~/.oh-my-zsh

ulimit -c unlimited 

# set Vim/NeoVim as pager

if (( $+commands[nvim] )); then
  export MANPAGER='nvim +Man!'
else
  export MANPAGER="vim +MANPAGER -c 'set nomod nolist nonu nornu buftype=nofile noswapfile nobackup' --not-a-term -"
fi

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="powerlevel10k/powerlevel10k"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in ~/.oh-my-zsh/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment the following line to disable bi-weekly auto-update checks.
# DISABLE_AUTO_UPDATE="true"

# Uncomment the following line to automatically update without prompting.
# DISABLE_UPDATE_PROMPT="true"

# Uncomment the following line to change how often to auto-update (in days).
# export UPDATE_ZSH_DAYS=13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS=true

# Uncomment the following line to disable colors in ls.
DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in ~/.oh-my-zsh/plugins/*
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# 
# git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
# git clone https://github.com/jeffreytse/zsh-vi-mode $ZSH_CUSTOM/plugins/zsh-vi-mode
# git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
# git clone https://github.com/Aloxaf/fzf-tab ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/fzf-tab
# git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
# Add wisely, as too many plugins slow down shell startup.
plugins=(
  fzf-tab # Must be the first one
  history-substring-search
  zsh-autosuggestions 
  zsh-syntax-highlighting
  dirhistory
  fasd
  fzf
  # zsh-vi-mode
)
ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets pattern line)
ZVM_VI_INSERT_ESCAPE_BINDKEY=jk

source $ZSH/oh-my-zsh.sh

# User configuration
# help for exa and fd
compdef _gnu_generic exa fd tldr
# Edit line in vim with ctrl-x-e
bindkey '^x^e' edit-command-line
bindkey '\ee' edit-command-line
                                     
export MANPATH="/usr/local/man:$MANPATH"
                                     
# You may need to manually set your language environment
export LANG=en_US.UTF-8              
                                     
# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

if (( $+commands[aichat] )); then
  eval_aichat() {
    aichat_reply=$(aichat -r shell $@)
    echo -n "Evaluate command:\n$aichat_reply\n[Y/n] "
    read response 
    echo
    if [[ "$response" != [nN] ]]; then
      echo "Executing: $aichat_reply"
      eval $aichat_reply
    fi
  }
  alias ai="aichat -r shell"
  alias aie=eval_aichat
fi

if (( $+commands[exa] ))
then
  # Changing "ls" to "exa"
  # Uncomment alias l* into /home/codac-dev/.oh-my-zsh/lib/directories.zsh
  # Uncomment DISABLE_LS_COLORS="true"
  alias ls='exa --icons --color=always --group-directories-first' # my preferred listing
  alias la='exa --icons -la --color=always --group-directories-first'  # all files and dirs
  alias ll='exa --icons -l --color=always --group-directories-first'  # long format
  # alias lt='exa -T --color=always --group-directories-first' # tree listing
fi

if (( $+commands[lazygit] ))
then
  alias lg='lazygit'
else
  alias lg='echo lazygit not installed'
fi

if (( $+commands[vim.gtk3] ))
then
  alias vim='vim.gtk3'
  export EDITOR=vim.gtk3
elif (( $+commands[vimx] ))
then
  alias vim='vimx'
  export EDITOR=vimx
else
  export EDITOR=vim
fi

if (( $+commands[nvim] ))
then
  export EDITOR=nvim
fi

if (( $+commands[fd] ))
then
  alias fd="fd --follow"
fi

if (( $+commands[fd] && $+commands[fzf] ))
then
  export FZF_DEFAULT_COMMAND='fd --follow --type f'
fi

if (( $+commands[zellij] )); then
  alias zla='zellij a $(zellij ls 2> /dev/null | fzf -0 -1)'
  eval "$(zellij setup --generate-completion zsh | grep "^function")"
fi

if (( $+commands[zsh] && $+commands[zellij] ))
then
  alias zellij="SHELL=zsh zellij"
fi

alias glp="git log --graph --abbrev-commit --decorate --date=relative --format=format:'\''%C(bold blue)%h%C(reset) - %C(bold green)(%ar)%C(reset) %C(white)%s%C(reset) %C(dim white)- %an%C(reset)%C(bold yellow)%d%C(reset)'\'' --all'"

if (( $+commands[fd] && $+commands[fzf-tmux] ))
then
  alias vv='fd --type f --hidden --exclude .git | fzf-tmux -p --reverse | xargs --no-run-if-empty -o "$EDITOR"'
else
  alias vv='echo "fd or fzf-tmux is missing!"'
fi

alias eh="file=`mktemp`.sh && tmux capture-pane -pS - > $file && $EDITOR '+ normal G $' $file"

if (( $+commands[bit] ))
then
  autoload -U +X bashcompinit && bashcompinit
  complete -o nospace -C /usr/local/bin/bit bit
  autoload -U +X bashcompinit && bashcompinit
  complete -o nospace -C /usr/local/bin/bit bit
fi

# broot
if [ -f ~/.config/broot/launcher/bash/br ]; then
  source ~/.config/broot/launcher/bash/br
  alias bs='br --sizes'
fi

if (( $+commands[ag] ))
then
  alias ag="ag -f" # follow symlinks
fi

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Created by `userpath` on 2020-12-16 07:36:51
export PATH="$PATH:$HOME/.local/bin:$HOME/.cargo/bin"

if [[ ! -z $(uname -a | grep "microsoft-standard-WSL2") ]]
then
  export DISPLAY=:0
else
  # export DISPLAY=localhost:0.0
fi

# stop pasted text being highlighted
zle_highlight+=('paste:none')


export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
