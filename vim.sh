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


mkdir -p ~/.vim/colors
cat > ~/.vim/colors/jacobm3.vim <<EOF
set background=dark
hi clear
if exists("syntax_on")
  syntax reset
endif
let colors_name = "jacobm3"
hi Normal ctermbg=Black ctermfg=LightGrey
hi ErrorMsg         	term=standout   ctermbg=DarkRed ctermfg=White
hi IncSearch        	term=reverse        	cterm=bold
hi ModeMsg                  	term=bold                   	cterm=bold
hi StatusLine   term=bold                   	cterm=bold
hi StatusLineNC term=bold                   	cterm=bold
hi VertSplit        	term=bold                   	cterm=bold
hi Visual                   	term=bold                   	cterm=reverse
hi VisualNOS        	term=underline,bold cterm=underline,bold
hi DiffText         	term=reverse cterm=bold ctermbg=grey
hi Directory        	term=bold ctermfg=cyan
hi LineNr                   	term=underline ctermfg=darkgrey
hi MoreMsg                  	term=bold ctermfg=LightGreen
hi NonText                  	term=bold ctermfg=darkgrey
hi Question         	term=standout ctermfg=LightGreen
hi Search                   	term=reverse ctermbg=Yellow ctermfg=Black
hi SpecialKey   term=bold ctermfg=grey
hi Title                            	term=bold ctermfg=darkGreen
hi WarningMsg   term=standout ctermfg=grey
hi WildMenu                 	term=standout ctermbg=Yellow ctermfg=Black
hi Folded                   	term=standout ctermbg=LightGrey ctermfg=grey
hi FoldColumn   term=standout ctermbg=LightGrey ctermfg=grey
hi DiffAdd                  	term=bold ctermbg=grey
hi DiffChange   term=bold ctermbg=cyan
hi DiffDelete   term=bold ctermfg=grey ctermbg=cyan
hi Comment                    	ctermfg=darkgrey
hi String                            	ctermfg=grey
hi Statement         	ctermfg=darkblue
hi Keyword           	ctermfg=darkblue
hi PreCondit         	ctermfg=darkblue
hi Function          	ctermfg=grey
hi Constant         	term=underline ctermfg=grey
hi Special                  	term=bold ctermfg=grey
if &t_Co > 8
  hi Statement  term=bold cterm=bold ctermfg=grey
endif
hi Ignore                   	ctermfg=LightGrey
EOF
