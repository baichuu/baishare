" Entry point for Vim 8.0 and 8.1.
if v:version < 800 || v:version >= 802
    echoerr 'Use this config with Vim 8.0 or 8.1'
    finish
endif

execute 'source ' . fnameescape(fnamemodify(resolve(expand('<sfile>:p')), ':h') . '/common.vim')
