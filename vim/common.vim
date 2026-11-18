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

" Enable true color for the inline Tokyo Night palette below.
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

" Search: ignore case unless the pattern contains a capital letter.
set ignorecase
set smartcase
set incsearch
set hlsearch

" Completion, buffers, and splits.
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

" Tokyo Night (night): a standalone Vim port with Tcl/tcsh highlights.
" Brighter local palette; token roles inspired by upstream Tree-sitter colors.
" Palette reference: https://github.com/folke/tokyonight.nvim
" Original theme by folke, Apache-2.0. Local Vim implementation and mappings.
set background=dark
highlight clear
if exists('syntax_on')
    syntax reset
endif

" Each color includes a 256-color approximation for non-true-color terminals.
let s:p = {
    \ 'none': ['NONE', 'NONE'],
    \ 'bg': ['#1a1b26', 234],
    \ 'dark': ['#16161e', 233],
    \ 'highlight': ['#292e42', 236],
    \ 'visual': ['#283457', 237],
    \ 'search': ['#3d59a1', 61],
    \ 'fg': ['#d5dfff', 189],
    \ 'fg_dark': ['#b4bfe5', 153],
    \ 'gutter': ['#3b4261', 60],
    \ 'comment': ['#828bb8', 103],
    \ 'blue': ['#82aaff', 111],
    \ 'cyan': ['#86e1fc', 117],
    \ 'teal': ['#4fd6be', 79],
    \ 'operator': ['#89ddff', 117],
    \ 'green': ['#b3e078', 149],
    \ 'magenta': ['#c099ff', 141],
    \ 'orange': ['#ffb07a', 215],
    \ 'red': ['#ff757f', 210],
    \ 'yellow': ['#ffc777', 222],
    \ 'diff_add': ['#20303b', 235],
    \ 'diff_change': ['#1f2231', 235],
    \ 'diff_delete': ['#37222c', 235],
    \ }

function! s:Hi(group, fg, bg, ...) abort
    let l:fg = s:p[a:fg]
    let l:bg = s:p[a:bg]
    let l:style = a:0 ? a:1 : 'NONE'
    execute 'highlight' a:group
        \ 'guifg=' . l:fg[0] 'guibg=' . l:bg[0]
        \ 'ctermfg=' . l:fg[1] 'ctermbg=' . l:bg[1]
        \ 'gui=' . l:style 'cterm=' . l:style
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
call s:Hi('BasicLinePosition', 'bg', 'blue', 'bold')
call s:Hi('TabLine', 'comment', 'dark')
call s:Hi('TabLineFill', 'none', 'dark')
call s:Hi('TabLineSel', 'bg', 'blue', 'bold')
call s:Hi('Pmenu', 'fg', 'dark')
call s:Hi('PmenuSel', 'fg', 'visual')
call s:Hi('PmenuSbar', 'none', 'highlight')
call s:Hi('PmenuThumb', 'none', 'gutter')
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
call s:Hi('SpellLocal', 'cyan', 'none', 'underline')
call s:Hi('SpellRare', 'teal', 'none', 'underline')

" Standard syntax groups, also used by Vim's other built-in languages.
call s:Hi('Comment', 'comment', 'none', 'italic')
call s:Hi('Constant', 'orange', 'none')
call s:Hi('String', 'green', 'none')
call s:Hi('Character', 'green', 'none')
call s:Hi('Number', 'orange', 'none')
call s:Hi('Boolean', 'orange', 'none')
call s:Hi('Float', 'orange', 'none')
call s:Hi('Identifier', 'cyan', 'none')
call s:Hi('Function', 'blue', 'none', 'bold')
call s:Hi('Statement', 'magenta', 'none')
call s:Hi('Conditional', 'magenta', 'none', 'bold')
call s:Hi('Repeat', 'magenta', 'none', 'bold')
call s:Hi('Label', 'magenta', 'none')
call s:Hi('Keyword', 'magenta', 'none', 'bold')
call s:Hi('Operator', 'operator', 'none')
call s:Hi('PreProc', 'cyan', 'none')
call s:Hi('Type', 'teal', 'none')
call s:Hi('Special', 'teal', 'none')
call s:Hi('Delimiter', 'teal', 'none')
call s:Hi('Underlined', 'blue', 'none', 'underline')
call s:Hi('Ignore', 'comment', 'none')
call s:Hi('Error', 'red', 'none')
call s:Hi('Todo', 'bg', 'yellow', 'bold')
call s:Hi('TokyoBuiltin', 'teal', 'none')
call s:Hi('TokyoBuiltinVariable', 'red', 'none')
call s:Hi('TokyoParameter', 'yellow', 'none')
call s:Hi('TokyoPunctuation', 'fg_dark', 'none')
call s:Hi('TokyoEscape', 'magenta', 'none')
highlight! link CurSearch IncSearch
highlight! link VisualNOS Visual
highlight! link WildMenu PmenuSel
highlight! link lCursor Cursor
highlight! link CursorIM Cursor

" Distinguish built-in calls, user functions, variables, and parameters.
highlight! link tclCommand TokyoBuiltin
highlight! link tcltkCommandColor TokyoBuiltin
highlight! link tclProcCommand Statement
highlight! link tclVarRef Identifier
highlight! link tclVars TokyoBuiltinVariable
highlight! link tclBoolean Boolean
highlight! link tclConditional Conditional
highlight! link tclRepeat Repeat
highlight! link tclString String
highlight! link tclNumber Number
highlight! link tclComment Comment
highlight! link tclSpecial TokyoEscape
highlight! link tclTNCommand Function
highlight! link tclTNProcName Function
highlight! link tclTNVariable Identifier
highlight! link tclTNParameter TokyoParameter
highlight! link tclTNParameterHead TokyoParameter
highlight! link tclTNBracket TokyoPunctuation
highlight! link tclTNOperator Operator

" tcsh's built-in syntax already handles substitutions, quotes, and redirects.
highlight! link tcshCommands Function
highlight! link tcshBuiltin TokyoBuiltin
highlight! link tcshUsrVar Identifier
highlight! link tcshShellVar TokyoBuiltinVariable
highlight! link tcshEnvVar TokyoBuiltinVariable
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
highlight! link tcshSpecial TokyoEscape
highlight! link tcshIf Conditional
highlight! link tcshTNConditional Conditional
highlight! link tcshTNRepeat Repeat
highlight! link tcshTNVariable Identifier
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
highlight! link verilogEscape TokyoEscape
highlight! link systemverilogStatement Statement
highlight! link systemverilogTypeDef Type
highlight! link systemverilogConditional Conditional
highlight! link systemverilogRepeat Repeat
highlight! link verilogTNIdentifier Identifier
highlight! link verilogTNType Type
highlight! link verilogTNDirection PreProc
highlight! link verilogTNDeclaration Statement
highlight! link verilogTNName Function
highlight! link verilogTNConstant Constant
highlight! link verilogTNMacro PreProc
highlight! link verilogTNSystemTask TokyoBuiltin
highlight! link verilogTNDelimiter TokyoPunctuation
highlight! link verilogTNNumber Number

delfunction s:Hi
unlet s:p
call s:LineNumberBackground()

function! s:TclSyntax() abort
    " Commands at statement starts, including namespaced calls and substitutions.
    " Built-in syntax keywords take priority over this generic match.
    syntax match tclTNCommand /\%(^\s*\|[;[]\s*\)\@<=\%(::\)\?\h[[:alnum:]_:]*/ containedin=tclEmbeddedStatement
    syntax match tclTNVariable /\%(\<\%(set\|unset\|variable\|incr\|append\|lappend\)\s\+\)\@<=\%(::\)\?\h[[:alnum:]_:]*/

    " Procedure names and argument lists, including {argument default} forms.
    syntax match tclTNProcName /\%(\<proc\s\+\)\@<=\%(::\)\?\h[[:alnum:]_:]*/ nextgroup=tclTNParameters skipwhite
    syntax region tclTNParameters matchgroup=TokyoPunctuation start=/{/ end=/}/ contained contains=tclTNParameter,tclTNDefault
    syntax match tclTNParameter /\h\w*/ contained
    syntax region tclTNDefault matchgroup=TokyoPunctuation start=/{/ end=/}/ contained contains=tclTNParameterHead,tclString,tclNumber
    syntax match tclTNParameterHead /\%({\s*\)\@<=\h\w*/ contained

    syntax match tclTNBracket /[][{}()]/
    syntax match tclTNOperator /==\|!=\|<=\|>=\|&&\|||\|[-+*\/%<>!]=\?/
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
    syntax keyword verilogTNType wire reg tri tri0 tri1 triand trior trireg wand wor
    syntax keyword verilogTNType integer real realtime time genvar signed unsigned
    syntax keyword verilogTNDirection input output inout
    syntax keyword verilogTNDeclaration module macromodule primitive
        \ nextgroup=verilogTNName skipwhite
    syntax match verilogTNName /[a-zA-Z_][a-zA-Z0-9_$]*/ contained

    if &l:syntax ==# 'systemverilog'
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
