if status is-interactive
        export EDITOR="vim"
	fastfetch
# Commands to run in interactive sessions can go here
end
set fish_greeting

alias clear='clear && fastfetch'

alias update='ujust update && brew update && brew upgrade'

function os-packedit
	cd ~/testin-/recipes/
	vim ~/testin-/recipes/recipe.yml
        git add recipe.yml
	git commit -m 'changes'
	git push origin main
	cd -
end

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

    chezmoi add $HOME/.config/packfile.lock

    chezmoi chattr create $HOME/.config/packfile.lock
end

function chezmoi
    if test "$argv[1]" = cd
        cd (command chezmoi source-path)
    else
        command chezmoi $argv
    end
end
