"---------------------------=== Default Section ===------------------------------
set nocompatible
filetype on
filetype plugin on
filetype plugin indent on
syntax enable
syntax on
set mouse=
set number
let mapleader=','

colorscheme turbo
set clipboard=unnamed
"" Encoding
set encoding=utf-8
set fileencoding=utf-8
set fileencodings=utf-8
set bomb
set binary
set ttyfast

"" Fix backspace indent
set backspace=indent,eol,start

"" Tabs. May be overriten by autocmd rules
set tabstop=2
set softtabstop=0
set shiftwidth=4
set expandtab
set showmatch
set ts=4
set sts=4
set sw=4
set autoindent
set smartindent
set smarttab
set expandtab

"" Fold mode
map <Space> za
autocmd Filetype * AnyFoldActivate
let g:anyfold_fold_comments=1
set foldlevel=0

"" Ale Linters
let b:ale_linters = {'terraform': ['tflint']}
let b:ale_linters = {'yaml.cloudformation': ['cfn_lint']}
let b:ale_linters = {'python': ['flake8', 'pylint']}
let b:ale_linters = {'markdown': ['mdl', 'writegood']}
let g:ale_list_window_size = 5
let g:ale_sign_error = '✘'
let g:ale_sign_warning = '⚠'
highlight ALEErrorSign ctermbg=NONE ctermfg=red
highlight ALEWarningSign ctermbg=NONE ctermfg=yellow

let g:airline#extensions#ale#enabled = 1



"Plugins
call plug#begin('~/.vim/plugged')
"---------------------------=== General Pluging ===------------------------------
Plug 'scrooloose/nerdtree'                " Project and file navigation
Plug 'jieyu/ftplugin.vim'
Plug 'dense-analysis/ale'                           " Async Lint Engine
"---------------------------=== Code Folding ===------------------------------
Plug 'pseewald/vim-anyfold'
"---------------------------=== Vim Airline     ===------------------------------
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
"---------------------------=== Cloudfromation  ===------------------------------
"Plug 'scrooloose/syntastic'        " Syntax checking plugin for Vim
Plug 'speshak/vim-cfn'             "CloudFormation syntax checking/highlighting
"---------------------------=== Python  ===-----------------------------
Plug 'habamax/vim-asciidoctor'
"---------------------------=== Python  ===-----------------------------
Plug 'klen/python-mode'                   " Python mode (docs, refactor, lints...)
Plug 'hynek/vim-python-pep8-indent'
Plug 'mitsuhiko/vim-python-combined'
Plug 'mitsuhiko/vim-jinja'
Plug 'jmcantrell/vim-virtualenv'
Plug 'majutsushi/tagbar'                  " Class/module browser
call plug#end()

"=====================================================
"" Ale Settings (Linting)
"=====================================================
" Use Ale.
" Show Ale in Airline
let g:airline#extensions#ale#enabled = 1

" Ale Gutter
let g:ale_sign_column_always = 1


"=====================================================
"" AirLine settings
"=====================================================
let g:airline#extensions#tabline#enabled=1
let g:airline#extensions#tabline#formatter='unique_tail'
let g:airline_powerline_fonts=1
let g:airline_theme = 'powerlineish'
let g:airline#extensions#syntastic#enabled = 1
let g:airline#extensions#branch#enabled = 1
let g:airline#extensions#tabline#enabled = 1
let g:airline#extensions#tagbar#enabled = 1
let g:airline_skip_empty_sections = 1

"=====================================================
"" Status settings
"=====================================================
set statusline+=%#warningmsg#
set statusline+=%*
"=====================================================
"" TagBar settings
"=====================================================
let g:tagbar_autofocus=0
let g:tagbar_width=42
nmap <F8> :TagbarToggle<CR>

"=====================================================
"" NERDTree settings
"=====================================================
let NERDTreeIgnore=['\.pyc$', '\.pyo$', '__pycache__$']     " Ignore files in NERDTree
let NERDTreeWinSize=40
nmap " :NERDTreeToggle<CR>

"=====================================================
"" NERDComment Settings
"=====================================================
" Add spaces after comment delimiters by default
let g:NERDSpaceDelims = 1

" Use compact syntax for prettified multi-line comments
let g:NERDCompactSexyComs = 1

"=====================================================
"" CFN Settings
"=====================================================
augroup cfn
    au!
    au BufNewFile,BufRead *.template* setlocal ft=yaml.cloudformation 
    au BufEnter *.template* colorscheme wombat256mod
    au BufEnter *.template* nnoremap <C-B> :!aws.cfn.validate.sh %:p<CR>

augroup END

"=====================================================
"" Python Settings
"=====================================================
augroup python
    au!
    au BufNewFile,BufRead *.py setlocal ft=python
    au BufEnter *.py colorscheme monokai
    au BufNewFile,BufRead *.py set foldlevel=0
	au FileType python setlocal textwidth=80 
	au FileType python map <F7> :w<CR>:!pylint "%"<CR>
augroup END

"=====================================================
"" Terraform Settings
"=====================================================
augroup terraform
    au!
    au BufNewFile,BufRead *.tf setlocal ft=terraform
    au BufNewFile,BufRead *.hcl setlocal ft=terraform
    au BufEnter *.tf colorscheme wombat256mod
augroup END

"=====================================================
"" Markdown Settings
"=====================================================
augroup markdown
    au!
    au BufNewFile,BufRead *.md setlocal ft=markdown
    au BufEnter *.md colorscheme summerfruit256
augroup END

"=====================================================
"" Asciidoctor Settings
"=====================================================
fun! AsciidoctorMappings()
    nnoremap <buffer> <leader>oo :AsciidoctorOpenRAW<CR>
    nnoremap <buffer> <leader>op :AsciidoctorOpenPDF<CR>
    nnoremap <buffer> <leader>oh :AsciidoctorOpenHTML<CR>
    nnoremap <buffer> <leader>ox :AsciidoctorOpenDOCX<CR>
    nnoremap <buffer> <leader>ch :Asciidoctor2HTML<CR>
    nnoremap <buffer> <leader>cp :Asciidoctor2PDF<CR>
    nnoremap <buffer> <leader>cx :Asciidoctor2DOCX<CR>
    nnoremap <buffer> <leader>p :AsciidoctorPasteImage<CR>
    " :make will build pdfs
    compiler asciidoctor2pdf
endfun

augroup asciidoctor
    au!
    au BufNewFile,BufRead *.adoc setlocal ft=asciidoc
    au BufEnter *.adoc colorscheme summerfruit256
    au BufEnter *.adoc,*.asciidoc call AsciidoctorMappings()
    au BufWritePost *.adoc Asciidoctor2HTML 
augroup END


