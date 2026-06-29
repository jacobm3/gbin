# vim.sh — write out a personal vim configuration and color scheme.
#
# This is a SOURCED/run fragment with no shebang. Running it (re)creates two
# files in your home directory:
#   ~/.vimrc                     vim's main config
#   ~/.vim/colors/jacobm3.vim    a custom dark color scheme used by that config
# WARNING: it OVERWRITES those files with `>`, so any manual edits there are
# lost. Re-run it to reset vim to this known-good setup on a new machine.

# Write the main vim config. `cat > FILE <<EOF ... EOF` is a "here-document":
# every line until the matching EOF is written verbatim into ~/.vimrc.
cat > ~/.vimrc  <<EOF
syntax on
set number
set ts=4
set autoindent
colorscheme jacobm3
set expandtab
set tabstop=4
set sw=4
EOF


# vim looks for color schemes under ~/.vim/colors/; create that folder if it
# doesn't exist yet (-p makes parent dirs as needed and won't error if present).
mkdir -p ~/.vim/colors
# Write the custom "jacobm3" color scheme. Each `hi` (highlight) line below sets
# the terminal colors for one syntax group (comments, strings, keywords, etc).
cat > ~/.vim/colors/jacobm3.vim <<EOF
set background=dark
hi clear
if exists("syntax_on")
  syntax reset
endif
let colors_name = "jacobm3"
hi Normal ctermbg=0 ctermfg=253
hi ErrorMsg         term=standout   ctermbg=DarkRed ctermfg=White
hi IncSearch        term=reverse        cterm=bold
hi StatusLine   term=bold                   cterm=bold
hi StatusLineNC term=bold                   cterm=bold
hi VertSplit        term=bold                   cterm=bold
hi Visual                   term=bold                   cterm=reverse
hi VisualNOS        term=underline,bold cterm=underline,bold
hi DiffText         term=reverse cterm=bold ctermbg=black
hi Directory        term=bold ctermfg=yellow
hi LineNr                   term=underline ctermfg=darkgrey
hi Question         term=standout ctermfg=LightGreen
hi Search                   term=reverse ctermbg=Yellow ctermfg=Black
hi WarningMsg   term=standout ctermfg=grey
hi WildMenu                 term=standout ctermbg=Yellow ctermfg=Black
hi Folded                   term=standout ctermbg=black ctermfg=grey
hi FoldColumn   term=standout ctermbg=black ctermfg=grey
hi Comment           ctermfg=246
hi String            ctermfg=081
hi Statement         ctermfg=119
hi Keyword           ctermfg=21
hi Include           ctermfg=21
hi PreCondit         ctermfg=21
hi Function          ctermfg=165
hi Constant         ctermfg=21
hi Define         ctermfg=165
hi Special          ctermfg=21
if &t_Co > 8
  hi Statement  ctermfg=21
endif
hi Ignore                   ctermfg=LightGrey

EOF
