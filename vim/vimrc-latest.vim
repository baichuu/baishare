" Entry point for modern Vim, currently targeting Vim 9.2.
if v:version < 900
    echoerr 'Use this config with Vim 9.0 or newer'
    finish
endif

execute 'source ' . fnameescape(fnamemodify(resolve(expand('<sfile>:p')), ':h') . '/common.vim')
