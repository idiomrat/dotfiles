function fish_prompt -d "Write out the prompt"
    # Set color to #aaaaff, print directory, print ' > ', and reset color
    printf '%s%s > ' (set_color aaaaff) (prompt_pwd)
    set_color normal
end
