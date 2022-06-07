filetype plugin indent on

" Specify a directory for plugins (for Neovim: ~/.local/share/nvim/plugged)
call plug#begin('~/.vim/plugged')

" my plugins

" Abolish for substitution stuff
Plug 'tpope/vim-abolish'

" Ack/ag/rg, etc.
Plug 'mileszs/ack.vim'
Plug 'jremmen/vim-ripgrep'

" Align
Plug 'godlygeek/tabular'
Plug 'junegunn/vim-easy-align'

" Filetype supports and linting
Plug 'dense-analysis/ale'
Plug 'sheerun/vim-polyglot'
Plug 'jngeist/vim-multimarkdown'
Plug 'vim-latex/vim-latex'
Plug 'julialang/julia-vim'
Plug 'rhysd/vim-crystal'
"Plug 'scrooloose/syntastic'

" Cosmetics
Plug 'bling/vim-airline'
Plug 'tomasiser/vim-code-dark'
Plug 'luochen1990/rainbow'
Plug 'yggdroot/indentline'

" Quick search and stuff
Plug 'Lokaltog/vim-easymotion'
Plug 'haya14busa/incsearch.vim'
Plug 'haya14busa/incsearch-easymotion.vim'

" Snippets and autocompletion
Plug 'garbas/vim-snipmate'
Plug 'ajh17/vimcompletesme'

" Easy editing
Plug 'terryma/vim-multiple-cursors'

" Nerdy stuff
Plug 'scrooloose/nerdcommenter'
Plug 'scrooloose/nerdtree'

" File search
Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all' }
Plug 'junegunn/fzf.vim'
Plug 'vim-scripts/mru.vim'

" etc
Plug 'majutsushi/tagbar'
Plug 'MarcWeber/vim-addon-mw-utils'
Plug 'vim-scripts/YankRing.vim'
"Plug 'tomtom/tlib_vim'


call plug#end()

" backspace over lines
set backspace=2

" auto-indent
set cin

" hides buffer instead of closing them
set hidden

" highlight search results during search
set hlsearch

" incremental search
set incsearch

" case-insensitive search
set ignorecase

" always show the status line
set laststatus=2

" to improve security
set modelines=0

" show line numbers as default
set nu

" set pastetoggle
set pastetoggle=<F2>

" set ruler, thus enabling status line
set ruler

" leave at least three lines below and above curser
set scrolloff=3

" show partial commands and size of visual block
set showcmd

" show matching parentheses
set showmatch

" show whether paste is on or off
set showmode

" yes, case-insensitve search, but only if all characters are lowwercase.
set smartcase

" tab stuffs 
set sts=2
set sw=2
set ts=2
set expandtab

" max number of tabs
set tabpagemax=100

" change the title of terminal
set title

" tell vil fast redrawing is available
set ttyfast

" correct creepy auto-completion of vim
set wildmode=longest:full
set wildmenu

syntax on
filetype on

" leader key
let mapleader=","

" bindings
nnoremap ; :
nnoremap j gj
nnoremap k gk
"vnoremap j gj
"vnoremap k gk
nnoremap <leader><space> :noh<cr>
nnoremap <leader>m :tabp<cr>
nnoremap <leader>. :tabn<cr>
nnoremap <leader>n :set nu!<cr>
nnoremap <leader>t :tabe 

vnoremap <Tab> >gv
vnoremap <S-Tab> <gv

nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

if has('nvim')
	tnoremap <C-h> <C-\><C-n><C-w>h
	tnoremap <C-j> <C-\><C-n><C-w>j
	tnoremap <C-k> <C-\><C-n><C-w>k
	tnoremap <C-l> <C-\><C-n><C-w>l
	tnoremap <Esc> <C-\><C-n>
endif

nnoremap <up> <nop>
nnoremap <down> <nop>
nnoremap <right> <nop>
nnoremap <left> <nop>
vnoremap <up> <nop>
vnoremap <down> <nop>
vnoremap <right> <nop>
vnoremap <left> <nop>

" set t_Co=256
colo codedark
" colo wombat256mod
" colo evening
"let g:seoul256_background = 234
"colo seoul256

" plugin-specific ones

" Abolish
nnoremap <leader>s :%Subvert/

" Airline
let g:airline#extensions#tabline#enabled = 1
let g:airline#extensions#whitespace#enabled = 1
"let g:airline_theme = "wombat"

" indentline
let g:indentLine_color_term = 237
let g:indentLine_color_gui = "#3a3a3a"
let g:indentLine_char = '│'

" nerdtree
nnoremap <leader>e <ESC>:NERDTreeToggle<CR>

" nerdcommenter
let g:NERDSpaceDelims = 1
let g:NERDDefaultAlign = 'left'

" syntastic
let g:syntastic_disabled_filetypes = ['tex', 'latex']

" tabular
vnoremap <leader><Tab> :Tabular /

" easyalign
" Start interactive EasyAlign in visual mode (e.g. vipga)
xmap ga <Plug>(EasyAlign)
" Start interactive EasyAlign for a motion/text object (e.g. gaip)
nmap ga <Plug>(EasyAlign)

" yankring
map <leader>y :YRShow<cr>
let g:yankring_replace_n_pkey = '<m-p>'
let g:yankring_replace_n_nkey = '<m-n>'

" easymotion
let g:EasyMotion_smartcase = 1
map <Leader>v <Plug>(easymotion-prefix)
"map <Leader><Leader> <Plug>(easymotion-prefix)
nmap s <Plug>(easymotion-s2)
"map  / <Plug>(easymotion-sn)

" incsearch
map /  <Plug>(incsearch-forward)
map ?  <Plug>(incsearch-backward)
map g/ <Plug>(incsearch-stay)

" incsearch-easymotion
map z/ <Plug>(incsearch-easymotion-/)
map z? <Plug>(incsearch-easymotion-?)
map zg/ <Plug>(incsearch-easymotion-stay)

" fzf
nnoremap <leader>f :FZF<CR>

" mru
nnoremap <leader>r :MRU<CR>

" snipmate
let g:snipMate = { 'snippet_version' : 1 }

" ale
let g:ale_linters = { "ruby": ['standardrb'] }
let g:ale_fixers = { "python": ['black', 'isort'], "ruby": ['standardrb'] }
let g:ale_python_flake8_options = '--max-line-length=88 --ignore=E203,E266,E501,E741,W391,W503'
let g:ale_python_isort_options = '--profile=black'
let g:ale_completion_enabled = 1