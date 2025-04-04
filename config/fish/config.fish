if status is-interactive
    # Commands to run in interactive sessions can go here
end

alias vim=nvim
set -x EDITOR nvim

mise activate fish | source


set -x SSH_AUTH_SOCK $XDG_RUNTIME_DIR/ssh-agent.socket
set -x SSH_AGENT_PID (pidof -s ssh-agent)
