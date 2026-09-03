if status is-interactive
        export EDITOR="vim"
	fastfetch
	    eval "$(zoxide init --cmd cd fish)"
# Commands to run in interactive sessions can go here
end
set fish_greeting

alias clear='clear && fastfetch'

alias update='ujust update && brew update && brew upgrade'

function dotfiles-push
    chezmoi re-add
    chezmoi git -- add .
    chezmoi git -- commit -m "$argv[1]"
    chezmoi git -- push origin main
end
