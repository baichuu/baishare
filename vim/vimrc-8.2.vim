" Entry point for Vim 8.2, including the original unpatched release.
if v:version != 802
    echoerr 'Use this config with Vim 8.2'
    finish
endif

execute 'source ' . fnameescape(fnamemodify(resolve(expand('<sfile>:p')), ':h') . '/common.vim')
