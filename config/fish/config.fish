if status is-interactive
    # Commands to run in interactive sessions can go here
end

alias vim=nvim
set -x EDITOR nvim

mise activate fish | source

# Added by LM Studio CLI (lms)
set -gx PATH $PATH /home/southporter/.lmstudio/bin
