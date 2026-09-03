if status is-interactive
        export EDITOR="vim"
	fastfetch
	    eval "$(zoxide init --cmd cd fish)"
# Commands to run in interactive sessions can go here
end
set fish_greeting

alias clear='clear && fastfetch'

alias update='ujust update && brew update && brew upgrade'

