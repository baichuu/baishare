" Entry point for Vim 8.2, including the original unpatched release.
if v:version != 802
    echoerr 'Use this config with Vim 8.2'
    finish
endif

" Basic Vim setup, using only built-in features.
set nocompatible
set noloadplugins
set encoding=utf-8
let g:filetype_csh = 'tcsh'   " Use tcsh syntax for .csh files and .cshrc
" Clear local syntax hooks before Vim rebuilds its built-in syntax hooks.
augroup LocalSyntax
    autocmd!
augroup END
unlet! g:colors_name
syntax enable
filetype indent on

" Include HDL headers that older Vim runtimes do not detect.
augroup LocalHDLFiletypes
    autocmd!
    autocmd BufRead,BufNewFile *.v,*.vh setfiletype verilog
    autocmd BufRead,BufNewFile *.sv,*.svh setfiletype systemverilog
augroup END

" Enable true color for the Gatekeeper palette.
if has('termguicolors')
    " Vim 8.0 lacks RGB capabilities for newer terminal names such as alacritty.
    if exists('+t_8f') && empty(&t_8f)
        let &t_8f = "\<Esc>[38;2;%lu;%lu;%lum"
    endif
    if exists('+t_8b') && empty(&t_8b)
        let &t_8b = "\<Esc>[48;2;%lu;%lu;%lum"
    endif
    set termguicolors
endif

" Display and navigation.
set mouse=a                 " Enable mouse scrolling and clicks in all modes
set number                  " Show line numbers
set numberwidth=5           " Add one column of left padding to the number gutter
set cursorline              " Highlight the current line
set ruler                   " Show cursor position
set showcmd                 " Show incomplete commands
set laststatus=2            " Always show the status line
set noshowmode              " Mode is displayed in the custom status line
set nowrap                  " Keep long lines on one screen row
set scrolloff=8             " Keep context above and below the cursor
set sidescrolloff=8
set showmatch               " Briefly highlight matching brackets

" Visual selections keep the current line number's foreground, without a background.
function! s:LineNumberBackground() abort
    let l:visual = index(['v', 'V'], mode(1)) >= 0
    let l:gui = l:visual ? 'NONE' : synIDattr(hlID('CursorLine'), 'bg', 'gui')
    let l:cterm = l:visual ? 'NONE' : synIDattr(hlID('CursorLine'), 'bg', 'cterm')
    execute 'highlight CursorLineNr guibg=' . (empty(l:gui) ? 'NONE' : l:gui)
        \ . ' ctermbg=' . (empty(l:cterm) ? 'NONE' : l:cterm)
endfunction

" Vim 8.0 has no ModeChanged event; check for mode changes without remapping keys.
function! s:PollMode(timer) abort
    let l:mode = mode(1)
    let l:bg = synIDattr(hlID('CursorLineNr'), 'bg', 'gui')
    let l:expected = index(['v', 'V'], l:mode) >= 0 ? '' : synIDattr(hlID('CursorLine'), 'bg', 'gui')
    if l:mode !=# get(s:, 'last_mode', '') || l:bg !=# l:expected
        let s:last_mode = l:mode
        call s:LineNumberBackground()
        redrawstatus
    endif
endfunction

if exists('s:mode_timer')
    call timer_stop(s:mode_timer)
    unlet s:mode_timer
endif
if !exists('##ModeChanged') && exists('*timer_start')
    let s:last_mode = ''
    let s:mode_timer = timer_start(50, function('<SID>PollMode'), {'repeat': -1})
endif

augroup BasicStatusLine
    autocmd!
    if exists('##ModeChanged')
        autocmd ModeChanged * call <SID>LineNumberBackground() | redrawstatus
    else
        autocmd InsertEnter,InsertLeave,CursorMoved * call <SID>LineNumberBackground() | redrawstatus
    endif
augroup END

" Indentation: four spaces by default; filetype rules can override this.
set expandtab
set tabstop=4
set shiftwidth=4
set softtabstop=4
set autoindent
set backspace=indent,eol,start

" Pair delimiters in Insert mode and keep cursor moves in the same undo block.
let s:pairs = {'(': ')', '[': ']', '{': '}', '"': '"', "'": "'"}

function! s:AutoPair(key) abort
    if mode() !=# 'i'
        return a:key
    endif

    let l:line = getline('.')
    let l:column = col('.') - 1
    let l:before = strpart(l:line, 0, l:column)
    let l:right = strpart(l:line, l:column, 1)

    if a:key ==# "\<BS>"
        let l:left = strpart(l:before, l:column - 1, 1)
        return !empty(l:right) && get(s:pairs, l:left, '') ==# l:right ? "\<BS>\<Del>" : a:key
    endif

    let l:closer = get(s:pairs, a:key, '')
    let l:is_quote = l:closer ==# a:key
    if l:is_quote && strlen(matchstr(l:before, '\\\+$')) % 2
        return a:key
    endif
    if a:key ==# l:right && (empty(l:closer) || l:is_quote)
        return "\<C-g>U\<Right>"
    endif
    if empty(l:closer) || strpart(l:line, l:column) =~# '^\k' || (a:key ==# "'" && l:before =~# '\k$')
        return a:key
    endif
    return a:key . l:closer . "\<C-g>U\<Left>"
endfunction

" Process earlier Insert keys before reading the cursor context.
for s:key in ['(', ')', '[', ']', '{', '}', '"', "'"]
    execute 'inoremap <script> ' . s:key . ' <C-g>U<SID>' . s:key
    execute 'inoremap <expr> <SID>' . s:key . ' <SID>AutoPair(' . string(s:key) . ')'
endfor
unlet s:key
inoremap <script> <BS> <C-g>U<SID><BS>
inoremap <expr> <SID><BS> <SID>AutoPair("\<BS>")

" Search: ignore case unless the pattern contains a capital letter.
set ignorecase
set smartcase
set incsearch
set hlsearch

" Completion, buffers, and splits.
set complete=.,w,b
if exists("+autocomplete")
    set complete=.^4,w^2,b^2  " Fit automatic suggestions within pumheight
endif
set completeopt=menuone,noinsert
if exists("+autocomplete")
    set autocomplete
    if exists("+autocompletedelay")
        set autocompletedelay=150
    endif
endif
" Select the first automatic suggestion without inserting it.
function! s:SelectFirstSuggestion() abort
    let l:completion = complete_info(['auto', 'selected'])
    if get(l:completion, 'auto', 0) && l:completion.selected < 0
                \ && get(b:, 'completion_preselect_tick', -1) != b:changedtick
        let b:completion_preselect_tick = b:changedtick
        call feedkeys("\<Plug>(SelectFirstSuggestion)", 'in')
    endif
endfunction
inoremap <expr> <Plug>(SelectFirstSuggestion)
    \ pumvisible() && get(complete_info(['auto']), 'auto', 0)
    \ && complete_info(['selected']).selected < 0 ? "\<Down>" : ""
" Older Vim can open its built-in keyword menu after a short pause.
function! s:StartKeywordCompletion(buffer, tick, timer) abort
    if mode() ==# 'i' && !&paste && !pumvisible()
                \ && bufnr('%') == a:buffer && b:changedtick == a:tick + 1
                \ && strpart(getline('.'), 0, col('.') - 1) =~# '\k$'
        call feedkeys("\<C-n>", 'in')
    endif
endfunction

function! s:ScheduleKeywordCompletion() abort
    if exists('s:completion_timer')
        call timer_stop(s:completion_timer)
    endif
    if !&paste && !pumvisible() && v:char =~# '^\k$'
        let s:completion_timer = timer_start(150,
                    \ function('<SID>StartKeywordCompletion', [bufnr('%'), b:changedtick]))
    endif
endfunction

augroup CompletionPreselect
    autocmd!
    if exists('+autocomplete') && exists('##CompleteChanged')
        autocmd CompleteChanged * call <SID>SelectFirstSuggestion()
        autocmd CompleteDone,InsertLeave * unlet! b:completion_preselect_tick
    elseif !exists('+autocomplete') && exists('*timer_start')
        autocmd InsertCharPre * call <SID>ScheduleKeywordCompletion()
    endif
augroup END
set pumheight=8
inoremap <expr> <Tab> pumvisible() ? "\<Down>" : "\<Tab>"
inoremap <expr> <S-Tab> pumvisible() ? "\<Up>" : "\<S-Tab>"
inoremap <expr> <CR> pumvisible() && (exists('*complete_info') ? complete_info(['selected']).selected >= 0 : 1) ? "\<C-y>" : "\<CR>"
set wildmenu
set wildmode=longest:full,full
set hidden                  " Allow switching away from unsaved buffers
set splitbelow
set splitright

" Share yanks with the desktop clipboard when X11 clipboard support is available.
" Ctrl-V pastes a single line into : commands and / or ? searches.
" Ctrl-Q retains Vim's original insert-next-character-literally behavior.
if has('unnamedplus') && !empty($DISPLAY)
    " Prepend: Vim 8.0's default exclude: pattern must remain the last item.
    set clipboard^=unnamedplus
endif

function! s:CommandPaste() abort
    let l:register = has('unnamedplus') && !empty($DISPLAY) ? '+' : '"'
    let l:text = getreg(l:register)
    " Linewise yanks and Windows clipboard text can include CR/LF characters.
    let l:text = substitute(l:text, '[\r\n]\+$', '', '')
    return substitute(l:text, '\r\n\|\r\|\n', ' ', 'g')
endfunction
cnoremap <C-v> <C-r>=<SID>CommandPaste()<CR>

" Keep undo history between sessions, outside project directories.
let s:undo_dir = expand('~/.vim/undo')
if !isdirectory(s:undo_dir)
    call mkdir(s:undo_dir, 'p', 0700)
endif
let &undodir = s:undo_dir . '//'
set undofile

" A small native statusline inspired by lightline's segment layout.
function! s:StatusLine() abort
    let l:winid = get(g:, 'statusline_winid', win_getid())
    if l:winid != win_getid()
        return '%#StatusLineNC# %<%f %h%m%r%w%=%l:%c '
    endif

    let l:mode = mode(1)
    if l:mode =~# '^i'
        let [l:label, l:color] = ['INSERT', 'Insert']
    elseif l:mode =~# '^R'
        let [l:label, l:color] = ['REPLACE', 'Replace']
    elseif index(['v', 'V', "\<C-v>"], l:mode) >= 0
        let l:label = l:mode ==# 'V' ? 'V-LINE' : l:mode ==# "\<C-v>" ? 'V-BLOCK' : 'VISUAL'
        let l:color = 'Visual'
    elseif index(['s', 'S', "\<C-s>"], l:mode) >= 0
        let [l:label, l:color] = ['SELECT', 'Visual']
    elseif l:mode =~# '^c'
        let [l:label, l:color] = ['COMMAND', 'Command']
    elseif l:mode ==# 't'
        let [l:label, l:color] = ['TERMINAL', 'Terminal']
    elseif l:mode =~# '^no'
        let [l:label, l:color] = ['OPERATOR', 'Normal']
    else
        let [l:label, l:color] = ['NORMAL', 'Normal']
    endif

    " Let Vim expand file/position items in the target window's context.
    " Native %f also handles filenames containing literal percent signs.
    let l:line = '%#BasicLine' . l:color . '# ' . l:label . ' '
        \ . '%#BasicLineFile# %<%f %h%m%r%w%#StatusLine#%='
    if winwidth(0) >= 70
        let l:line .= ' %{empty(&filetype) ? "text" : &filetype} '
    endif
    if winwidth(0) >= 100
        let l:line .= '| %{empty(&fileencoding) ? &encoding : &fileencoding} | %{&fileformat} '
    endif
    return l:line . '%#BasicLinePosition# %3p%% %l:%c '
endfunction

" expand('<SID>') is unavailable in early Vim 8.0; resolve it inside a function.
function! s:ScriptPrefix() abort
    return matchstr(expand('<sfile>'), '<SNR>\d\+_')
endfunction
let &statusline = '%!' . s:ScriptPrefix() . 'StatusLine()'
" Older Vim does not pass statusline_winid; give inactive windows a static line.
let s:active_statusline = &statusline
let s:inactive_statusline = '%#StatusLineNC# %<%f %h%m%r%w%=%l:%c '
augroup BasicStatusLine
    autocmd WinEnter,BufWinEnter * let &l:statusline = s:active_statusline
    autocmd WinLeave * let &l:statusline = s:inactive_statusline
augroup END
let &l:statusline = s:active_statusline

" Gatekeeper from the NvChad Base46 palette exported by Theme Sync.
set background=dark
highlight clear
if exists('syntax_on')
    syntax reset
endif

" Each color includes a 256-color approximation for non-true-color terminals.
let s:palette = {
    \ 'none': ['NONE', 'NONE'],
    \ 'bg': ['#101010', 233],
    \ 'dark': ['#0a0a0a', 232],
    \ 'highlight': ['#1e1e1e', 234],
    \ 'visual': ['#252525', 235],
    \ 'search': ['#1a4e6f', 23],
    \ 'fg': ['#d8d9dd', 253],
    \ 'fg_dark': ['#cccdd1', 252],
    \ 'gutter': ['#363636', 237],
    \ 'comment': ['#4d4d4d', 239],
    \ 'blue': ['#29adff', 39],
    \ 'teal': ['#0b925c', 29],
    \ 'green': ['#00e756', 41],
    \ 'magenta': ['#a79ac0', 139],
    \ 'orange': ['#ffa300', 214],
    \ 'red': ['#ff1a67', 197],
    \ 'yellow': ['#fff024', 226],
    \ 'diff_add': ['#0c3b1e', 235],
    \ 'diff_change': ['#152f3f', 236],
    \ 'diff_delete': ['#3f1221', 235],
    \ 'identifier': ['#ffb20f', 214],
    \ 'number': ['#ff004d', 197],
    \ 'type': ['#be620a', 130],
    \ 'function': ['#c54bcf', 170],
    \ 'keyword': ['#ff4394', 204],
    \ 'punctuation': ['#ffccaa', 223],
    \ }

let s:highlight_roles = {}

function! s:Hi(group, fg, bg, ...) abort
    let s:highlight_roles[a:group] = [a:fg, a:bg, a:0 ? a:1 : 'NONE']
endfunction

function! s:ApplyTheme() abort
    for [l:group, l:roles] in items(s:highlight_roles)
        let l:fg = s:palette[l:roles[0]]
        let l:bg = s:palette[l:roles[1]]
        execute 'highlight' l:group
            \ 'guifg=' . l:fg[0] 'guibg=' . l:bg[0]
            \ 'ctermfg=' . l:fg[1] 'ctermbg=' . l:bg[1]
            \ 'gui=' . l:roles[2] 'cterm=' . l:roles[2]
    endfor
    " Keep Vim from inferring a light background from the terminal color index.
    if &background !=# 'dark'
        set background=dark
    endif
    call s:LineNumberBackground()
endfunction

" Editor interface.
call s:Hi('Normal', 'fg', 'bg')
call s:Hi('NormalNC', 'fg', 'bg')
call s:Hi('EndOfBuffer', 'bg', 'bg')
call s:Hi('NonText', 'gutter', 'none')
call s:Hi('SpecialKey', 'gutter', 'none')
call s:Hi('Whitespace', 'gutter', 'none')
call s:Hi('LineNr', 'gutter', 'none')
call s:Hi('CursorLineNr', 'orange', 'highlight', 'bold')
call s:Hi('CursorLine', 'none', 'highlight')
call s:Hi('CursorLineSign', 'gutter', 'highlight')
call s:Hi('CursorLineFold', 'comment', 'highlight')
call s:Hi('CursorColumn', 'none', 'highlight')
call s:Hi('ColorColumn', 'none', 'dark')
call s:Hi('Cursor', 'bg', 'fg')
call s:Hi('SignColumn', 'gutter', 'bg')
call s:Hi('FoldColumn', 'comment', 'bg')
call s:Hi('Folded', 'blue', 'highlight')
call s:Hi('VertSplit', 'gutter', 'bg')
call s:Hi('StatusLine', 'fg_dark', 'dark')
call s:Hi('StatusLineNC', 'gutter', 'dark')
" Native statusline segments; mode colors follow the editor palette.
call s:Hi('BasicLineNormal', 'bg', 'blue', 'bold')
call s:Hi('BasicLineInsert', 'bg', 'green', 'bold')
call s:Hi('BasicLineVisual', 'bg', 'magenta', 'bold')
call s:Hi('BasicLineReplace', 'bg', 'red', 'bold')
call s:Hi('BasicLineCommand', 'bg', 'yellow', 'bold')
call s:Hi('BasicLineTerminal', 'bg', 'teal', 'bold')
call s:Hi('BasicLineFile', 'fg', 'highlight')
call s:Hi('BasicLinePosition', 'fg_dark', 'highlight', 'bold')
call s:Hi('TabLine', 'comment', 'dark')
call s:Hi('TabLineFill', 'none', 'dark')
call s:Hi('TabLineSel', 'bg', 'blue', 'bold')
call s:Hi('Pmenu', 'fg', 'dark')
call s:Hi('PmenuSel', 'fg', 'visual')
call s:Hi('PmenuSbar', 'none', 'dark')
call s:Hi('PmenuThumb', 'none', 'dark')
call s:Hi('PmenuMatch', 'teal', 'dark')
call s:Hi('PmenuMatchSel', 'teal', 'visual')
call s:Hi('Visual', 'none', 'visual')
call s:Hi('Search', 'fg', 'search')
call s:Hi('IncSearch', 'bg', 'orange')
call s:Hi('MatchParen', 'orange', 'none', 'bold')
call s:Hi('Directory', 'blue', 'none')
call s:Hi('Title', 'blue', 'none', 'bold')
call s:Hi('ModeMsg', 'fg_dark', 'none', 'bold')
call s:Hi('MoreMsg', 'blue', 'none')
call s:Hi('Question', 'blue', 'none')
call s:Hi('WarningMsg', 'yellow', 'none')
call s:Hi('ErrorMsg', 'red', 'none')
call s:Hi('QuickFixLine', 'none', 'visual', 'bold')
call s:Hi('DiffAdd', 'none', 'diff_add')
call s:Hi('DiffChange', 'none', 'diff_change')
call s:Hi('DiffDelete', 'red', 'diff_delete')
call s:Hi('DiffText', 'none', 'visual', 'bold')
call s:Hi('SpellBad', 'red', 'none', 'underline')
call s:Hi('SpellCap', 'yellow', 'none', 'underline')
call s:Hi('SpellLocal', 'blue', 'none', 'underline')
call s:Hi('SpellRare', 'teal', 'none', 'underline')

" Gatekeeper's Base46 syntax colors and its Tree-sitter variable overrides.
call s:Hi('Comment', 'comment', 'none', 'italic')
call s:Hi('Constant', 'number', 'none')
call s:Hi('String', 'green', 'none')
call s:Hi('Character', 'identifier', 'none')
call s:Hi('Number', 'number', 'none')
call s:Hi('Boolean', 'number', 'none')
call s:Hi('Float', 'number', 'none')
call s:Hi('Identifier', 'identifier', 'none')
call s:Hi('Function', 'function', 'none', 'bold')
call s:Hi('Statement', 'identifier', 'none')
call s:Hi('Conditional', 'keyword', 'none', 'bold')
call s:Hi('Repeat', 'type', 'none', 'bold')
call s:Hi('Label', 'type', 'none')
call s:Hi('Keyword', 'keyword', 'none', 'bold')
call s:Hi('Exception', 'identifier', 'none')
call s:Hi('Operator', 'fg', 'none')
call s:Hi('PreProc', 'type', 'none')
call s:Hi('Include', 'function', 'none')
call s:Hi('Define', 'keyword', 'none')
call s:Hi('Macro', 'identifier', 'none')
call s:Hi('Type', 'type', 'none')
call s:Hi('StorageClass', 'type', 'none')
call s:Hi('Structure', 'keyword', 'none')
call s:Hi('Typedef', 'type', 'none')
call s:Hi('Special', 'blue', 'none')
call s:Hi('SpecialChar', 'punctuation', 'none')
call s:Hi('Delimiter', 'punctuation', 'none')
call s:Hi('Underlined', 'blue', 'none', 'underline')
call s:Hi('Ignore', 'comment', 'none')
call s:Hi('Error', 'red', 'none')
call s:Hi('Todo', 'bg', 'yellow', 'bold')
call s:Hi('GatekeeperBuiltin', 'function', 'none')
call s:Hi('GatekeeperVariable', 'orange', 'none')
call s:Hi('GatekeeperParameter', 'fg_dark', 'none')
highlight! link GatekeeperBuiltinVariable Number
highlight! link GatekeeperEscape Special
highlight! link CurSearch IncSearch
highlight! link VisualNOS Visual
highlight! link WildMenu PmenuSel
highlight! link lCursor Cursor
highlight! link CursorIM Cursor

" Map Tree-sitter token roles onto the palette's highlight groups.
highlight! link cTNFunction Function
highlight! link cTNBuiltin GatekeeperBuiltin
highlight! link cTNConstant Constant
highlight! link cTNMacro Macro
highlight! link cTNType Type
highlight! link cTNMember Identifier
highlight! link cTNOperator Operator
highlight! link cSpecial GatekeeperEscape
highlight! link cppTNNamespace Identifier
highlight! link cppTNThis GatekeeperBuiltinVariable

highlight! link pythonTNCall Function
highlight! link pythonTNClass Type
highlight! link pythonTNConstant Constant
highlight! link pythonTNReceiver GatekeeperBuiltinVariable
highlight! link pythonTNAttribute Identifier
highlight! link pythonTNOperator Operator
highlight! link pythonTNBoolean Boolean
highlight! link pythonStatement Keyword
highlight! link pythonAsync Keyword
highlight! link pythonBuiltin GatekeeperBuiltin
highlight! link pythonEscape GatekeeperEscape

highlight! link makeStatement GatekeeperBuiltin
highlight! link makePreCondit Conditional
highlight! link makeSpecial Operator
highlight! link makeTNAutomatic GatekeeperBuiltinVariable
highlight! link makeTNAssignment Operator
highlight! link makeTNRecipe Function

" Distinguish built-in calls, user functions, variables, and parameters.
highlight! link tclCommand GatekeeperBuiltin
highlight! link tcltkCommandColor GatekeeperBuiltin
highlight! link tclProcCommand Keyword
highlight! link tclVarRef GatekeeperVariable
highlight! link tclVars GatekeeperBuiltinVariable
highlight! link tclBoolean Boolean
highlight! link tclConditional Conditional
highlight! link tclRepeat Repeat
highlight! link tclString String
highlight! link tclNumber Number
highlight! link tclComment Comment
highlight! link tclSpecial GatekeeperEscape
highlight! link tclTNCommand Function
highlight! link tclTNProcName Function
highlight! link tclTNVariable GatekeeperVariable
highlight! link tclTNParameter GatekeeperParameter
highlight! link tclTNParameterHead GatekeeperParameter
highlight! link tclTNBracket Delimiter
highlight! link tclTNOperator Operator
highlight! link tclTNVariableRef GatekeeperVariable
highlight! link tclTNExpand Operator
highlight! link tclExpand Operator

" tcsh's built-in syntax already handles substitutions, quotes, and redirects.
highlight! link tcshCommands Function
highlight! link tcshBuiltin GatekeeperBuiltin
highlight! link tcshUsrVar GatekeeperVariable
highlight! link tcshShellVar GatekeeperBuiltinVariable
highlight! link tcshEnvVar GatekeeperBuiltinVariable
highlight! link tcshAliCmd Function
highlight! link tcshAliases Function
highlight! link tcshArgument Special
highlight! link tcshArguement Special
highlight! link tcshSQuote String
highlight! link tcshDQuote String
highlight! link tcshOperator Operator
highlight! link tcshRedir Operator
highlight! link tcshNumber Number
highlight! link tcshComment Comment
highlight! link tcshSpecial GatekeeperEscape
highlight! link tcshIf Conditional
highlight! link tcshTNConditional Conditional
highlight! link tcshTNRepeat Repeat
highlight! link tcshTNVariable GatekeeperVariable
highlight! link tcshTNAssignment Operator

" Verilog/SystemVerilog: signals, types, module names, macros, and system tasks.
highlight! link verilogStatement Statement
highlight! link verilogConditional Conditional
highlight! link verilogRepeat Repeat
highlight! link verilogOperator Operator
highlight! link verilogNumber Number
highlight! link verilogConstant Constant
highlight! link verilogString String
highlight! link verilogComment Comment
highlight! link verilogGlobal PreProc
highlight! link verilogEscape GatekeeperEscape
highlight! link systemverilogStatement Statement
highlight! link systemverilogTypeDef Type
highlight! link systemverilogConditional Conditional
highlight! link systemverilogRepeat Repeat
highlight! link verilogTNIdentifier GatekeeperVariable
highlight! link verilogTNType Type
highlight! link verilogTNDirection PreProc
highlight! link verilogTNDeclaration Keyword
highlight! link verilogTNName Function
highlight! link verilogTNConstant Constant
highlight! link verilogTNMacro Macro
highlight! link verilogTNSystemTask GatekeeperBuiltin
highlight! link verilogTNDelimiter Delimiter
highlight! link verilogTNNumber Number
highlight! link verilogTNCall Function
highlight! link verilogTNParameter Constant
highlight! link verilogTNBuiltinHandle GatekeeperBuiltinVariable

call s:ApplyTheme()

function! s:CFamilySyntax() abort
    syntax match cTNConstant /\<[A-Z][A-Z0-9_]\+\>/
    syntax match cTNType /\<\h\w*_t\>/
    syntax match cTNType /\%(\<\%(struct\|union\|enum\|class\)\s\+\)\@<=\h\w*/
    syntax match cTNMember /\%(\.\|->\)\@<=\h\w*/
    syntax match cTNFunction /\<\h\w*\ze\_s*(/
    syntax match cTNBuiltin /\<__builtin_\w\+\ze\_s*(/
    syntax match cTNMacro /\%(^\s*#\s*\%(define\|undef\)\s\+\)\@<=\h\w*/ containedin=cDefine
    " Keep comment starts and C's digraph brackets available to the runtime.
    syntax match cTNOperator /->\|\/[/*]\@!\|[-+*=!&|^~?]\|%[:>]\@!\|<[:%]\@!\|[:%]\@<!>/

    if &l:syntax ==# 'cpp'
        syntax match cppTNNamespace /\<\h\w*\ze::/
        syntax match cTNFunction /\<\h\w*\ze<[^<>();{}]*>\s*(/
        syntax keyword cppTNThis this
    endif
endfunction

function! s:PythonSyntax() abort
    syntax match pythonTNConstant /\<[A-Z][A-Z0-9_]\+\>/
    syntax keyword pythonTNBoolean True False
    syntax keyword pythonTNConstant None
    syntax keyword pythonTNReceiver self cls
    syntax keyword pythonStatement class nextgroup=pythonTNClass skipwhite
    syntax match pythonTNClass /\h\w*/ contained
    syntax match pythonTNAttribute /\.\@<=\h\w*/ containedin=pythonAttribute,pythonFStringField
    syntax match pythonTNCall /\<\h\w*\ze\s*(/ containedin=pythonAttribute,pythonFStringField
    syntax match pythonTNOperator /->\|[-+*\/%<>=!&|^~]/ containedin=pythonFStringField
endfunction

function! s:MakeSyntax() abort
    " The runtime links these directives when it loads the Make syntax.
    highlight! link makeExport Statement
    highlight! link makeOverride Statement


    syntax match makeTNAutomatic /\$\@<!\$\%([@%<^+?*|]\|([@%<^+?*|][DF]\?)\|{[@%<^+?*|][DF]\?}\)/
        \ containedin=makeIdent,makeCommands,makeDString,makeSString
    syntax match makeTNAssignment /\%(^ *[^#:=+?! \t]\+ *\)\@<=\%(:::\|::\|[:+?!]\)\?=/
    syntax match makeTNRecipe /\%(^\t[@+-]*[ \t]*\)\@<=\h[[:alnum:]_.-]*/ containedin=makeCommands
endfunction

function! s:TclSyntax() abort
    " Commands at statement starts, including namespaced calls and substitutions.
    " Built-in syntax keywords take priority over this generic match.
    syntax match tclTNCommand /\%(^\s*\|[;[]\s*\)\@<=\%(::\)\?\h[[:alnum:]_:]*/ containedin=tclEmbeddedStatement
    syntax match tclTNVariable /\%(\<\%(set\|unset\|variable\|incr\|append\|lappend\)\s\+\)\@<=\%(::\)\?\h[[:alnum:]_:]*/

    " Procedure names and argument lists, including {argument default} forms.
    syntax match tclTNProcName /\%(\<proc\s\+\)\@<=\%(::\)\?\h[[:alnum:]_:]*/ nextgroup=tclTNParameters skipwhite
    syntax region tclTNParameters matchgroup=Delimiter start=/{/ end=/}/ contained contains=tclTNParameter,tclTNDefault
    syntax match tclTNParameter /\h\w*/ contained
    syntax region tclTNDefault matchgroup=Delimiter start=/{/ end=/}/ contained contains=tclTNParameterHead,tclString,tclNumber
    syntax match tclTNParameterHead /\%({\s*\)\@<=\h\w*/ contained

    syntax match tclTNBracket /[][{}()]/
    syntax match tclTNOperator /==\|!=\|<=\|>=\|&&\|||\|[-+*\/%<>!]=\?/
    " Preserve the runtime's built-in variable names inside substitutions.
    syntax match tclTNVariableRef /\$\%(\%(::\)\?\h\w*\>\%(::\)\@!\|{\%(::\)\?\h\w*}\)/
        \ contains=tclVars containedin=tclString,tclEmbeddedStatement
    syntax match tclTNExpand /\%(\s\|[;[]\)\@<={\*}\ze\S/ contained containedin=tclEmbeddedStatement
endfunction

function! s:TcshSyntax() abort
    " Ordinary assignments and arguments otherwise miss numeric highlighting.
    syntax cluster tcshStatementEnds add=tcshNumber,tcshTNVariable,tcshTNAssignment
    syntax match tcshTNVariable /\%(\<\%(set\|setenv\|unset\|unsetenv\)\s\+\)\@<=\h\w*/ contained
    syntax match tcshTNAssignment /[+*\/%-]\?=/ contained

    " Keep the built-in nextgroup rules so conditions/arguments still parse.
    syntax keyword tcshTNConditional endif switch case default endsw nextgroup=tcshStatementEnd
    syntax keyword tcshTNConditional else nextgroup=tcshIf skipwhite
    syntax keyword tcshTNRepeat foreach repeat end break breaksw continue nextgroup=tcshStatementEnd
    syntax keyword tcshTNRepeat while nextgroup=@tcshConditions,tcshSpecial skipwhite
endfunction

function! s:VerilogSyntax() abort
    " Keywords take priority over generic signal names; strings/comments stay intact.
    syntax match verilogTNIdentifier /\<[a-zA-Z_][a-zA-Z0-9_$]*\>/
    syntax match verilogTNIdentifier /\\\S\+/
    syntax match verilogTNConstant /\<[A-Z_][A-Z0-9_$]*\>/
    syntax match verilogTNMacro /`\h\w*/
    syntax match verilogTNSystemTask /\$\h\w*/
    syntax match verilogTNDelimiter /[][(){};,.]/
    syntax match verilogTNCall /\<[a-zA-Z_][a-zA-Z0-9_$]*\ze\_s*(/
    " Verilog also permits function and task declarations without parentheses.
    syntax match verilogTNCall /\%(^\s*\%(function\|task\)\s\+\%([^;()]*\s\)\?\)\@<=[a-zA-Z_][a-zA-Z0-9_$]*\ze\s*;/
    syntax match verilogTNParameter /\%(\<\%(parameter\|localparam\)\s\+\%([^=;(),]*\s\)\?\)\@<=[a-zA-Z_][a-zA-Z0-9_$]*\ze\s*=/
    syntax keyword verilogTNType wire reg tri tri0 tri1 triand trior trireg wand wor
    syntax keyword verilogTNType integer real realtime time genvar signed unsigned
    syntax keyword verilogTNDirection input output inout
    syntax keyword verilogTNDeclaration module macromodule primitive
        \ nextgroup=verilogTNName skipwhite
    syntax match verilogTNName /[a-zA-Z_][a-zA-Z0-9_$]*/ contained

    if &l:syntax ==# 'systemverilog'
        syntax keyword verilogTNBuiltinHandle this super
        syntax keyword verilogTNType logic bit byte shortint int longint shortreal
        syntax keyword verilogTNType string void chandle struct union enum packed
        syntax keyword verilogTNDeclaration interface package program class
            \ nextgroup=verilogTNName skipwhite
        " SystemVerilog unbased, unsized literals: '0, '1, 'x, 'z.
        syntax match verilogTNNumber /'[01xXzZ]\>/
    endif
endfunction

function! s:SyntaxHooks() abort
    augroup LocalSyntax
        autocmd!
        autocmd Syntax c,cpp call <SID>CFamilySyntax()
        autocmd Syntax python call <SID>PythonSyntax()
        autocmd Syntax make call <SID>MakeSyntax()
        autocmd Syntax tcl call <SID>TclSyntax()
        autocmd Syntax tcsh call <SID>TcshSyntax()
        autocmd Syntax verilog,systemverilog call <SID>VerilogSyntax()
        " Keep our hooks after Vim's loader when syntax is toggled off/on.
        if exists('##SourcePost')
            autocmd SourcePost */syntax/synload.vim call <SID>SyntaxHooks()
        elseif exists('*timer_start')
            autocmd SourcePre */syntax/synload.vim call timer_start(0, function('<SID>RefreshSyntax'))
        endif
    augroup END
endfunction

function! s:RefreshSyntax(timer) abort
    call s:SyntaxHooks()
    doautoall <nomodeline> syntaxset FileType
endfunction
call s:SyntaxHooks()

" Refresh syntax in existing buffers when this file is sourced again.
doautoall <nomodeline> syntaxset FileType
