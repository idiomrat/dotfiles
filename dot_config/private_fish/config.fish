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

function packedit --description 'Edit packfile, apply, run packctl, and re-add the lockfile'
    set -l target $argv[1]
    if test -z "$target"
        set target ~/.config/packfile
    end

    chezmoi edit $target
    or return 1

    chezmoi apply
    or return 1

    chezmoi re-add
end

function chezmoi
    if test "$argv[1]" = cd
        cd (command chezmoi source-path)
    else
        command chezmoi $argv
    end
end
