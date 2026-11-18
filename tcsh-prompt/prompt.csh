# Square blocks for tcsh: directory, date/time, exit status, runtime, history.
# Runtime uses tcsh's command hooks and GNU date's millisecond clock.
# Exact RGB colors from the NvChad Base46 TokyoDark palette.
# Accent blocks use #11121d text; the exit block uses #abb2bf on #1d1e29.
set path_block = "%{\033[48;2;113;153;238;38;2;17;18;29m%}"
set user_text  = "%{\033[38;2;246;149;91m%}"
set time_block = "%{\033[48;2;164;133;221;38;2;17;18;29m%}"
set exit_block = "%{\033[48;2;29;30;41;38;2;171;178;191m%}"
set run_block  = "%{\033[48;2;215;166;95;38;2;17;18;29m%}"
set hist_block = "%{\033[48;2;81;154;186;38;2;17;18;29m%}"
set cyan       = "%{\033[38;2;56;168;157m%}"
set reset      = "%{\033[0m%}"

# Preserve existing hooks once, so sourcing this file again is safe.
if (! $?_tcsh_prompt_hooks_installed) then
    alias _tcsh_prompt_previous_precmd ':'
    alias _tcsh_prompt_previous_postcmd ':'
    set _tcsh_prompt_old_hook = "`alias precmd`"
    if ("$_tcsh_prompt_old_hook" != "") alias _tcsh_prompt_previous_precmd "$_tcsh_prompt_old_hook"
    set _tcsh_prompt_old_hook = "`alias postcmd`"
    if ("$_tcsh_prompt_old_hook" != "") alias _tcsh_prompt_previous_postcmd "$_tcsh_prompt_old_hook"
    unset _tcsh_prompt_old_hook
    set _tcsh_prompt_hooks_installed = 1
endif

set _tcsh_prompt_start_time = (0 0)
set _tcsh_prompt_exit = 0
set _tcsh_prompt_runtime = "0ms"

# Keep seconds and milliseconds separate to fit tcsh's integer arithmetic.
alias _tcsh_prompt_start 'set _tcsh_prompt_start_time = (`date "+%s %3N"`)'
alias _tcsh_prompt_finish 'set _tcsh_prompt_exit = $status; set _tcsh_prompt_end_time = (`date "+%s %3N"`); @ _tcsh_prompt_elapsed = 0; if ($_tcsh_prompt_start_time[1] > 0) @ _tcsh_prompt_elapsed = ($_tcsh_prompt_end_time[1] - $_tcsh_prompt_start_time[1]) * 1000 + $_tcsh_prompt_end_time[2] - $_tcsh_prompt_start_time[2]; if ($_tcsh_prompt_elapsed < 0) @ _tcsh_prompt_elapsed = 0; set _tcsh_prompt_runtime = "${_tcsh_prompt_elapsed}ms"; @ _tcsh_prompt_seconds = $_tcsh_prompt_elapsed / 1000; @ _tcsh_prompt_fraction = ($_tcsh_prompt_elapsed % 1000) / 10; if ($_tcsh_prompt_fraction < 10) set _tcsh_prompt_fraction = "0${_tcsh_prompt_fraction}"; if ($_tcsh_prompt_elapsed >= 1000) set _tcsh_prompt_runtime = "${_tcsh_prompt_seconds}.${_tcsh_prompt_fraction}s"; set _tcsh_prompt_start_time = (0 0)'
# Keep short paths intact; show the final two folders when ancestors are hidden.
# Native path modifiers preserve spaces and avoid an external path formatter.
alias _tcsh_prompt_path_update 'set _tcsh_prompt_parent = "$cwd:h"; set _tcsh_prompt_grandparent = "$_tcsh_prompt_parent:h"; set _tcsh_prompt_path = "/.../$_tcsh_prompt_parent:t/$cwd:t"; if ("$_tcsh_prompt_grandparent" == "" || "$_tcsh_prompt_grandparent" == "/") set _tcsh_prompt_path = "$cwd"; if ("$cwd" =~ "$home"/*) set _tcsh_prompt_path = "~/.../$_tcsh_prompt_parent:t/$cwd:t"; if ("$_tcsh_prompt_grandparent" == "$home") set _tcsh_prompt_path = "~/$_tcsh_prompt_parent:t/$cwd:t"; if ("$_tcsh_prompt_parent" == "$home") set _tcsh_prompt_path = "~/$cwd:t"; if ("$cwd" == "$home") set _tcsh_prompt_path = "~"'
alias postcmd '_tcsh_prompt_previous_postcmd; _tcsh_prompt_start'
alias precmd '_tcsh_prompt_finish; _tcsh_prompt_previous_precmd; _tcsh_prompt_path_update'
_tcsh_prompt_path_update

# One space inside each background block on both sides.
# The visible space after reset keeps tcsh's newline/cursor accounting correct.
set prompt = "${path_block} "'%$_tcsh_prompt_path'" ${time_block} %D/%W/%Y %T ${exit_block} exit "'%$_tcsh_prompt_exit'" ${run_block} "'%$_tcsh_prompt_runtime'" ${hist_block} #%h ${reset} \n${user_text}%n@%m ${cyan}❯${reset} "
