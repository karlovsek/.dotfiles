source ~/.vimcommon

set ttymouse=sgr

"Set shell
if executable("zsh")
    set shell=zsh
endif

let g:mapleader = " "

" Disable formating on new line or paste
au BufEnter * set formatoptions-=r formatoptions-=c formatoptions-=o

" " Paste enhancements
" vnoremap <leader>P .pu +
" vnoremap <leader>p "_dP

" Switch between tabs
nmap <leader>1 1gt
nmap <leader>2 2gt
nmap <leader>3 3gt
nmap <leader>4 4gt
nmap <leader>5 5gt
nmap <leader>6 6gt
nmap <leader>7 7gt
nmap <leader>8 8gt
nmap <leader>9 9gt

" Select all text
noremap vA ggVG

"Mode Settings
augroup OnlyInActiveWindow
  autocmd!
  autocmd VimEnter,WinEnter,BufWinEnter * setlocal cursorline
  autocmd WinLeave * setlocal nocursorline
  autocmd WinEnter * set relativenumber
  autocmd WinLeave * set norelativenumber
augroup END

let &t_SI.="\e[5 q" "SI = INSERT mode
let &t_SR.="\e[3 q" "SR = REPLACE mode
let &t_EI.="\e[2 q" "EI = NORMAL mode (ELSE)

" ====== Fix for <M-j|k> moving lines =======  {{{
if $GNOME_SHELL_SESSION_MODE != "" || $SSH_CLIENT != ""
  " echom "In GNOME shell or ssh" . $SSH_CLIENT
  let &t_TI = ""
  let &t_TE = ""

  " MOVE LINE/BLOCK
  " Workaround for Alt to work in Gnome terminal :(
  let c='a'
  while c <= 'z'
    exec "set <A-".c.">=\e".c
    exec "imap \e".c." <A-".c.">"
    let c = nr2char(1+char2nr(c))
  endw
endif
" }}}

" ====== GNOME TERMINAL SETTINGS =======  {{{
" ========== Cursor settings: ===============
" {{{
"  1 -> blinking block
"  2 -> solid block 
"  3 -> blinking underscore
"  4 -> solid underscore
"  5 -> blinking vertical bar
"  6 -> solid vertical bar

if has("autocmd") && $GNOME_SHELL_SESSION_MODE != ""
  " echo "Changing cursors in GNOME SHELL"
  au VimEnter,InsertLeave * silent execute '!echo -ne "\e[2 q"' | redraw!
  au InsertEnter,InsertChange *
    \ if v:insertmode == 'i' | 
    \   silent execute '!echo -ne "\e[5 q"' | redraw! |
    \ elseif v:insertmode == 'r' |
    \   silent execute '!echo -ne "\e[3 q"' | redraw! |
    \ endif
  au VimLeave * silent execute '!echo -ne "\e[ q"' | redraw!
endif
" }}}
" ========== END Cursor settings ==============
" }}}

" copy (write) highlighted text to .vimbuffer
if has("win32")
vmap <C-S-c> y:new ~/.vimbuffer<CR>VGp:x<CR> \| :!cat ~/.vimbuffer \| clip.exe <CR><CR>
" paste from buffer
map <C-S-v> :r ~/.vimbuffer<CR>
endif

function! s:DiffWithSaved()
  let filetype=&ft
  diffthis
  vnew | r # | normal! 1Gdd
  diffthis
  exe "setlocal bt=nofile bh=wipe nobl noswf ro ft=" . filetype
endfunction
com! DiffSaved call s:DiffWithSaved()

" cross-platform 
set clipboard^=unnamed,unnamedplus

syntax on

if !empty($CONEMUBUILD)
  set term=pcansi
  set t_Co=256
  let &t_AB="\e[48;5;%dm"
  let &t_AF="\e[38;5;%dm"
  set bs=indent,eol,start
  colorscheme wombat256mod
else
  " colorscheme gruvbox
  " colorscheme colorsbox-stbright
endif

set encoding=utf-8

" reset to vim-defaults
if &compatible          " only if not set before:
  set nocompatible      " use vim-defaults instead of vi-defaults (easier, more user friendly)
endif

" display settings
set background=dark     " enable for dark terminals
set nowrap              " dont wrap lines
set scrolloff=2         " 2 lines above/below cursor when scrolling
set number              " show line numbers
set relativenumber      " show relative number
set showmatch           " show matching bracket (briefly jump)
set showmode            " show mode in status bar (insert/replace/...)
set showcmd             " show typed command in status bar
set ruler               " show cursor position in status bar
set title               " show file in titlebar
set wildmenu            " completion with menu
set wildignore=*.o,*.obj,*.bak,*.exe,*.py[co],*.swp,*~,*.pyc,.svn
set laststatus=2        " use 2 lines for the status bar
set matchtime=2         " show matching bracket for 0.2 seconds
set matchpairs+=<:>     " specially for html

" editor settings
set esckeys             " map missed escape sequences (enables keypad keys)
set ignorecase          " case insensitive searching
set smartcase           " but become case sensitive if you type uppercase characters
set smartindent         " smart auto indenting
set smarttab            " smart tab handling for indenting
set magic               " change the way backslashes are used in search patterns
set bs=indent,eol,start " Allow backspacing over everything in insert mode

set tabstop=2           " number of spaces a tab counts for
set shiftwidth=2        " spaces for autoindents
set expandtab           " turn a tabs into spaces

set fileformat=unix     " file mode is unix
"set fileformats=unix,dos    " only detect unix file format, displays that ^M with dos files

" system settings
set lazyredraw          " no redraws in macros
" set noswapfile          " disable creating of *.swp files
set confirm             " get a dialog when :q, :w, or :wq fails
" set nobackup            " no backup~ files.
set viminfo='100,\"500   " remember copy registers after quitting in the .viminfo file -- 20 jump links, regs up to 500 lines'
set hidden              " remember undo after quitting
set history=5000        " keep #N lines of command history
set mouse=a             " use mouse in visual mode (not normal,insert,command,help mode


" color settings (if terminal/gui supports it)
if &t_Co > 2 || has("gui_running")
  syntax on          " enable colors
  set hlsearch       " highlight search (very useful!)
  set incsearch      " search incremently (search while typing)
  if has("gui_gtk2")
    set guifont=Inconsolata\ 12
  elseif has("gui_macvim")
    set guifont=Menlo\ Regular:h14
  elseif has("gui_win32")
    set guifont=Consolas:h11:cANSI
    "set guifont=DejaVuSansMono_NF:h9:cEASTEUROPE:qDRAFT 
    colorscheme colorsbox-stbright
  endif
endif

" paste mode toggle (needed when using autoindent/smartindent)
map <F10> :set paste<CR>
map <F11> :set nopaste<CR>
imap <F10> <C-O>:set paste<CR>
imap <F11> <nop>
set pastetoggle=<F11>

" Use of the filetype plugins, auto completion and indentation support
filetype plugin indent on

" file type specific settings
if has("autocmd")
  " For debugging
  "set verbose=9

  " if bash is sh.
  let bash_is_sh=1

  " change to directory of current file automatically
  " Causes some problems in gitguttter and do not need it
  " augroup AutoChdir
  "   autocmd!
  "   autocmd BufEnter * if &buftype != 'terminal' | lcd %:p:h | endif
  " augroup END

  " Put these in an autocmd group, so that we can delete them easily.
  augroup mysettings
    au FileType xslt,xml,css,html,xhtml,javascript,sh,config,c,cpp,docbook set smartindent shiftwidth=2 softtabstop=2 expandtab
    au FileType tex set wrap shiftwidth=2 softtabstop=2 expandtab
    " Uncomment if pressing <tab> takes too long
    autocmd FileType c,cpp setlocal complete-=i

    " Confirm to PEP8
    au FileType python set tabstop=4 softtabstop=4 expandtab shiftwidth=4 cinwords=if,elif,else,for,while,try,except,finally,def,class
  augroup END

  " Always jump to the last known cursor position. 
  " Don't do it when the position is invalid or when inside
  " an event handler (happens when dropping a file on gvim). 
  autocmd BufReadPost * 
    \ if line("'\"") > 0 && line("'\"") <= line("$") | 
    \   exe "normal g`\"" | 
    \ endif 

endif " has("autocmd")

" Plugins "

" Install and run vim-plug on first run
if has("win32")
    if !filereadable(expand('$HOME\vimfiles\autoload\plug.vim'))
      echo "plug.vim is not installed , installing"
      let current_shell = &shell
      echo "Current shell is " current_shell
      set shell=powershell
      silent !"iwr -useb https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim |` ni $HOME/vimfiles/autoload/plug.vim -Force"
      let &shell=current_shell
    endif
elseif empty(glob('~/.vim/autoload/plug.vim'))
    silent !curl -fLo ~/.vim/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
    autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

call plug#begin('~/.vim/plugged')
Plug 'gioele/vim-autoswap' " {{{
" Please Vim, stop with these swap file messages. Just switch to the correct window!
" Linux users: you must install wmctrl to be able to automatically switch to the Vim window with the open file.
set title titlestring=
let g:autoswap_detect_tmux = 1
" }}}
Plug 'bogado/file-line' " {{{
"When you open a file:line, for instance when coping and pasting from an error from your compiler vim tries to open a file with a colon in its name.
" }}}
Plug 'easymotion/vim-easymotion' " {{{
" <Leader>f{char} to move to {char}
map  f <Plug>(easymotion-bd-f)
nmap f <Plug>(easymotion-overwin-f)

map <Leader>j <Plug>(easymotion-j)
map <Leader>k <Plug>(easymotion-k)
" }}}
" {{{ clipboard
Plug 'svermeulen/vim-cutlass'
" {{{ Cutlass overrides the delete operations to actually just delete and not affect the current yank.
" use for cutting
nnoremap m d
xnoremap m d

nnoremap mm dd
nnoremap M D
" }}} // Cutlass
Plug 'svermeulen/vim-yoink'
" Yoink will automatically maintain a history of yanks that you can choose between when pasting. {{{
let  g:yoinkSyncNumberedRegisters    =  1
let  g:yoinkIncludeDeleteOperations  =  1
let  g:yoinkMoveCursorToEndOfPaste   =  1
nmap <c-n> <plug>(YoinkPostPasteSwapBack)
nmap <c-p> <plug>(YoinkPostPasteSwapForward)

nmap <leader>p o<Esc><plug>(YoinkPaste_p)
nmap <leader>P O<Esc><plug>(YoinkPaste_P)
nmap p <plug>(YoinkPaste_p)
nmap P <plug>(YoinkPaste_P)
" }}} // Yonk
Plug 'svermeulen/vim-subversive'
" {{{
nmap s <plug>(SubversiveSubstitute)
nmap ss <plug>(SubversiveSubstituteLine)
nmap S <plug>(SubversiveSubstituteToEndOfLine)
" }}}
" }}} // clipboard
" For live preview of replace
" https://github.com/markonm/traces.vim ~/.vim/pack/plugins/start/traces.vim
Plug 'rafi/awesome-vim-colorschemes' " {{{
set runtimepath+=~/.vim/plugged/awesome-vim-colorschemes
  colorscheme gruvbox
" colorscheme PaperColor
" colorscheme afterglow
" }}}
Plug 'chrisbra/Colorizer'
" LSP testing 
Plug 'neoclide/coc.nvim', {'branch': 'release'} " {{{
" Always show the signcolumn, otherwise it would shift the text each time
" diagnostics appear/become resolved.
set signcolumn=yes

" Use tab for trigger completion with characters ahead and navigate.
" NOTE: Use command ':verbose imap <tab>' to make sure tab is not mapped by
" other plugin before putting this into your config.
inoremap <silent><expr> <TAB>
      \ pumvisible() ? "\<C-n>" :
      \ <SID>check_back_space() ? "\<TAB>" :
      \ coc#refresh()
inoremap <expr><S-TAB> pumvisible() ? "\<C-p>" : "\<C-h>"

function! s:check_back_space() abort
  let col = col('.') - 1
  return !col || getline('.')[col - 1]  =~# '\s'
endfunction

" Use <c-space> to trigger completion.
if has('nvim')
  inoremap <silent><expr> <c-space> coc#refresh()
else
  inoremap <silent><expr> <c-@> coc#refresh()
endif

" Make <CR> auto-select the first completion item and notify coc.nvim to
" format on enter, <cr> could be remapped by other vim plugin
inoremap <silent><expr> <cr> pumvisible() ? coc#_select_confirm()
                              \: "\<C-g>u\<CR>\<c-r>=coc#on_enter()\<CR>"

" Use `[g` and `]g` to navigate diagnostics
" Use `:CocDiagnostics` to get all diagnostics of current buffer in location list.
nmap <silent> [g <Plug>(coc-diagnostic-prev)
nmap <silent> ]g <Plug>(coc-diagnostic-next)

" GoTo code navigation.
nmap <silent> gd <Plug>(coc-definition)
nmap <silent> gy <Plug>(coc-type-definition)
nmap <silent> gi <Plug>(coc-implementation)
nmap <silent> gr <Plug>(coc-references)
nmap <silent> gs :CocCommand clangd.switchSourceHeader<CR>

" Use K to show documentation in preview window.
nnoremap <silent> K :call <SID>show_documentation()<CR>

function! s:show_documentation()
  if (index(['vim','help'], &filetype) >= 0)
    execute 'h '.expand('<cword>')
  elseif (coc#rpc#ready())
    call CocActionAsync('doHover')
  else
    execute '!' . &keywordprg . " " . expand('<cword>')
  endif
endfunction

" Highlight the symbol and its references when holding the cursor.
autocmd CursorHold * silent call CocActionAsync('highlight')

" Symbol renaming.
nmap <leader>rn <Plug>(coc-rename)

" Formatting selected code.
xmap <M-l>  <Plug>(coc-format)
nmap <M-l>  <Plug>(coc-format)
" }}}
Plug 'jackguo380/vim-lsp-cxx-highlight'
Plug 'ap/vim-css-color'
" must be after colorscheme execution
Plug 'machakann/vim-highlightedyank'
highlight HighlightedyankRegion ctermfg=0 ctermbg=208 guifg=#000000 guibg=#ff8700 
" if has("unix") && has('python3')
"   Plug 'puremourning/vimspector'
" endif
" " {{{
"   let g:vimspector_enable_mappings = 'HUMAN'
" " }}}
Plug 'szw/vim-maximizer' " {{{
  "Whether Maximizer should set default mappings or not:
  let g:maximizer_set_default_mapping = 1
  let g:maximizer_default_mapping_key = '<F2>'
  let g:maximizer_set_mapping_with_bang = 0
" }}}
Plug 'tpope/vim-dispatch'
Plug 'ilyachur/cmake4vim' " {{{
let g:cmake_compile_commands = 1
let g:cmake_compile_commands_link = '.'
" }}}
" Plug 'cdelledonne/vim-cmake'
" Plug 'foonathan/vim-cmake', {'as':'vim-cmake', 'branch':'feature/cmake_build_directory'} " " {{{
"   let g:cmake_build_directory = '..'
"   let g:cmake_link_compile_commands = 1
" " }}}
Plug 'dbeniamine/cheat.sh-vim'
Plug 'tpope/vim-obsession'
Plug 'fedorenchik/qt-support.vim'
Plug 'iamcco/markdown-preview.nvim', { 'do': { -> mkdp#util#install() } }
Plug 'itchyny/lightline.vim'
Plug 'junegunn/fzf'
Plug 'junegunn/fzf.vim' " {{{
  nnoremap <silent> <leader>f   :Files<CR>
  nnoremap <silent> <leader>gf   :GFiles<CR>
  nnoremap <silent> <leader>b   :Buffers<CR>
  nnoremap <silent> <leader>?  :History<CR>
  nnoremap <silent> <leader>L   :BLines<CR>
  nnoremap <silent> <leader>l   :Lines<CR>
  nnoremap <silent> <leader>c   :Commits<CR>
  nnoremap <leader>a   :Ag 
  nmap <silent> cc :Commands!<CR>
" }}}
Plug 'scrooloose/nerdtree' " {{{
  let g:NERDTreeMinimalUI = 1
  let g:NERDTreeHijackNetrw = 0
  let g:NERDTreeWinSize = 31
  let g:NERDTreeChDirMode = 2
  let g:NERDTreeAutoDeleteBuffer = 1
  let g:NERDTreeShowBookmarks = 1
  let g:NERDTreeCascadeOpenSingleChildDir = 1

  " Check if NERDTree is open or active
  function! IsNERDTreeOpen()
    return exists("t:NERDTreeBufName") && (bufwinnr(t:NERDTreeBufName) != -1)
  endfunction

  function! CheckIfCurrentBufferIsFile()
    return strlen(expand('%')) > 0
  endfunction

  " Call NERDTreeFind iff NERDTree is active, current window contains a modifiable
  " file, and we're not in vimdiff
  function! SyncTree()
    if &modifiable && IsNERDTreeOpen() && CheckIfCurrentBufferIsFile() && !&diff
      NERDTreeFind
      wincmd p
    endif
  endfunction

  " Highlight currently open buffer in NERDTree
  autocmd BufRead * call SyncTree()

  function! ToggleTree()
    if CheckIfCurrentBufferIsFile()
      if IsNERDTreeOpen()
        NERDTreeClose
      else
        NERDTreeFind
      endif
    else
      NERDTree
    endif
  endfunction

  " open NERDTree with ctrl + n
  nmap <F3> :call ToggleTree()<CR>
  " }}}
Plug 'mhinz/vim-startify' " {{{
  " remove cow header
  let g:startify_custom_header =['     >>>>  Startify VIM <<<<']
  let g:startify_change_to_dir = 0
  let g:startify_change_to_dir = 1
" }}}
Plug 'tpope/vim-commentary'
Plug 'mhinz/vim-signify'
Plug 'airblade/vim-gitgutter' " {{{
  set updatetime=500
  let g:gitgutter_preview_win_floating = 1
" }}}
Plug 'tpope/vim-fugitive'
Plug 'tyru/open-browser.vim'
" {{{
  let g:netrw_nogx = 1
  vmap gx <Plug>(openbrowser-smart-search)
  nmap gx <Plug>(openbrowser-search)
" }}}
Plug 'Shougo/junkfile.vim' " {{{
  nnoremap <leader>JO :JunkfileOpen 
  let g:junkfile#directory = $HOME . '/.vim/cache/junkfile'
" }}}
Plug 'junegunn/vim-peekaboo' " {{{
  let g:peekaboo_delay = 400
  let g:peekaboo_window = "vert bo 40new"
" }}}

call plug#end()
let g:deoplete#enable_at_startup = 1

" Customizing signify
nnoremap <leader>gd :SignifyDiff<cr>
nnoremap <leader>gp :SignifyHunkDiff<cr>
nnoremap <leader>gu :SignifyHunkUndo<cr>

" hunk jumping
nmap <leader>gj <plug>(signify-next-hunk)
nmap <leader>gk <plug>(signify-prev-hunk)

" hunk text object
" omap ic <plug>(signify-motion-inner-pending)
" xmap ic <plug>(signify-motion-inner-visual)
" omap ac <plug>(signify-motion-outer-pending)
" xmap ac <plug>(signify-motion-outer-visual)

" Customizig LightLine
function! LightlineObsession()
  let s = ''
  if exists('g:this_obsession')
    let s .= '%#DiffChange#' " Use the "DiffAdd" color if in a session
  endif
  let s .= "%{ObsessionStatus()}"
  if exists('v:this_session') && v:this_session != ''
    let s:obsession_string = v:this_session
    let s:obsession_parts = split(s:obsession_string, '/')
    if len(s:obsession_parts) == 1
      " windows path seperator
      let s:obsession_parts = split(s:obsession_string, '\\')
    endif
    let s:obsession_filename = s:obsession_parts[-1]
    let s .= ' ' . s:obsession_filename
    " let s .= '%*' " Restore default color
  endif
  return s
endfunction

let g:lightline = {
      \ 'active': {
      \   'right': [ [ 'lineinfo' ],
      \              [ 'percent' ],
      \              [ 'fileformat', 'fileencoding', 'filetype'], 
      \              [ 'obsession' ]]
      \ },
      \ 'component_expand': {
      \   'obsession': 'LightlineObsession'
      \ },
    \ }

" ~~~~~~~~~~~~~~~~~~ Session configuration ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
let g:sessions_dir = '~/vim-sessions'
set sessionoptions-=blank

" Remaps for Sessions
exec 'nnoremap <Leader>ss :Obsession '. g:sessions_dir . '/*.vim<C-D><BS><BS><BS><BS><BS>'
exec 'nnoremap <Leader>sr :so ' . g:sessions_dir . '/*.vim<C-D><BS><BS><BS><BS><BS>'



" ~~~~~~~~~~~~~~~~~~~~~~~~~ End Session configurations ~~~~~~~~~~~~~~~

" " autocmd! " Remove ALL autocommands for the current group.
" if executable('/home/codac-dev/Documents/clangd/build/bin/clangd-temp')
"     augroup lsp_clangd
"         autocmd!
"         autocmd User lsp_setup call lsp#register_server({
"                     \ 'name': 'clangd',
"                     \ 'cmd': {server_info->['/home/codac-dev/Documents/clangd/build/bin/clangd', '--background-index']},
"                     \ 'whitelist': ['c', 'cpp'],
"                     \ })
"         autocmd FileType cpp setlocal omnifunc=lsp#complete
"     augroup end
" endif

" function! s:on_lsp_buffer_enabled() abort
"     setlocal omnifunc=lsp#complete
" 		setlocal signcolumn=yes
"     if exists('+tagfunc') | setlocal tagfunc=lsp#tagfunc | endif
"     nmap <buffer> gd <plug>(lsp-definition)
"     nmap <buffer> gr <plug>(lsp-references)
"     nmap <buffer> gi <plug>(lsp-implementation)
"     " nmap <buffer> gt <plug>(lsp-type-definition)
"     nmap <buffer> gs <plug>(lsp-switch-source-header)
"     nmap <buffer> <leader>rn <plug>(lsp-rename)
"     nmap <buffer> [g <Plug>(lsp-previous-diagnostic)
"     nmap <buffer> ]g <Plug>(lsp-next-diagnostic)
"     nmap <buffer> K <plug>(lsp-hover)
 
"     " refer to doc to add more commands
" endfunction

" augroup lsp_install
"     au!
"     " call s:on_lsp_buffer_enabled only for languages that has the server registered.
"     autocmd User lsp_buffer_enabled call s:on_lsp_buffer_enabled()
" augroup END

nnoremap <silent> <leader>gg :tab term ++close lazygit<CR>
" vim: set sw=2 ts=2 et foldlevel=0 foldmethod=marker:
