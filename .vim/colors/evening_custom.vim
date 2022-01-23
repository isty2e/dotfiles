" Vim color file
" Maintainer:	Bram Moolenaar <Bram@vim.org>
" Last Change:	2006 Apr 14

" This color scheme uses a dark grey background.

" First remove all existing highlighting.
set background=dark

hi clear

if exists("syntax_on")
	syntax reset
endif

let colors_name = "evening_custom"

" Groups used in the 'highlight' and 'guicursor' options default value.
" General colors
hi Normal		ctermfg=254		ctermbg=234		guifg=White		guibg=grey20
hi Cursor		guifg=Black		guibg=Green
hi Visual		ctermbg=238		term=reverse	guibg=grey60
hi VisualNOS	cterm=underline,bold	term=underline,bold		gui=underline,bold
hi Search		ctermfg=Black	ctermbg=249		term=reverse	guifg=Black		guibg=#b2b2b2
hi Folded		ctermfg=103		ctermbg=238		cterm=none		term=standout	guifg=#a0a8b0	guibg=#384048	gui=none
hi Title		ctermfg=LightMagenta			term=bold		guifg=Magenta	gui=bold 
hi StatusLine	cterm=reverse,bold		term=reverse,bold	gui=reverse,bold
hi VertSplit	cterm=reverse	term=reverse	gui=reverse
hi StatusLineNC	cterm=reverse	term=reverse	gui=reverse
hi LineNr		ctermfg=243		term=underline	guifg=#857b6f
hi SpecialKey	ctermfg=LightBlue				term=bold		guifg=Cyan
hi NonText		ctermfg=LightBlue	term=bold   guifg=LightBlue	guibg=grey30	gui=bold

hi ErrorMsg		ctermfg=White	ctermbg=DarkRed	term=standout	guifg=White		guibg=Red 
hi IncSearch	ctermfg=Black	ctermbg=249		term=reverse	gui=reverse
hi ModeMsg		cterm=bold		term=bold		gui=bold
hi DiffText		ctermbg=Red		cterm=bold		term=reverse	guibg=Red		gui=bold 
hi lCursor		guifg=Black		guibg=Cyan 
hi Directory	ctermfg=LightCyan	term=bold	guifg=Cyan
hi MoreMsg		ctermfg=LightGreen	term=bold	guifg=SeaGreen	gui=bold 
hi Question		ctermfg=LightGreen	term=standout	guifg=Green		gui=bold 
hi WarningMsg	ctermfg=LightRed	term=standout	guifg=Red
hi WildMenu		ctermfg=Black	ctermbg=Yellow	term=standout	guifg=Black		guibg=Yellow
hi FoldColumn	ctermfg=DarkBlue	ctermbg=LightGrey	term=standout	guifg=DarkBlue	guibg=Grey 
hi DiffAdd		ctermbg=DarkBlue	term=bold	guibg=DarkBlue
hi DiffChange	ctermbg=DarkMagenta	term=bold	guibg=DarkMagenta
hi DiffDelete	ctermfg=Blue	ctermbg=DarkCyan	term=bold	guifg=Blue		guibg=DarkCyan	gui=bold
hi CursorColumn	ctermbg=Black	term=reverse	guibg=grey40
hi CursorLine	cterm=underline	term=underline	guibg=grey40

" Groups for syntax highlighting
hi Constant		ctermfg=Magenta	term=underline	guifg=#ffa0a0	guibg=grey5
hi Special		ctermfg=LightRed	term=bold	guifg=Orange	guibg=grey5
if &t_Co > 8
hi Statement	ctermfg=Yellow	cterm=bold		term=bold		guifg=#ffff60	gui=bold
endif
hi Ignore		ctermfg=DarkGrey	guifg=grey20

" vim:set ts=4 sw=4 noet:
