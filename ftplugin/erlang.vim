" Erlang refactor file
" Language:   Erlang
" Maintainer: Pawel 'kTT' Salata <rockplayer.pl@gmail.com>
" URL:        http://ktototaki.info

if exists("s:did_ftplugin_erlang_refator")
    finish
endif

let s:diff_script = expand('<sfile>:p:h') . "/../scripts/diff.sh"
let s:clean_script = expand('<sfile>:p:h') . "/../scripts/clean.sh"

" Don't load any other
let s:did_ftplugin_erlang_refator=1

if !exists('g:erlangRefactoring') 
    let g:erlangRefactoring=1
endif

if g:erlangRefactoring == 0
    echom "g:erlangRefactoring equal to zero"
    finish
endif

if !exists('g:erlangWranglerPath')
    let g:erlangWranglerPath = '/usr/share/wrangler/'
endif

if glob(g:erlangWranglerPath) == ""
    echom "Wrong path to wrangler dir"
    finish
endif

"I don't think start and sotp it again and again is a good idea
"another problem is that, once a vi is exist, all other vim can not use it 
"autocmd VimLeavePre * call StopWranglerServer()

let s:erlangServerName = "wrangler_vim@127.0.0.1"

" Starting background erlang session with wrangler on
function! StartWranglerServer()
    let wranglerEbinDir = g:erlangWranglerPath . "/ebin"
    let command = "erl -detached -name " . s:erlangServerName . " -pa " . wranglerEbinDir
    call system(command)
    call s:send_rpc('application', 'start', '[wrangler]')
endfunction

" Stopping erlang session
function! StopWranglerServer()
    call s:send_rpc('erlang', 'halt', '')
endfunction

"uncomment the following codes if you wanna debug this script

"function! RefactorLogFunc(s)
"    echom a:s
"endfunction

function! s:Log(s)
    if exists("*RefactorLogFunc")
        call RefactorLogFunc(a:s)
    endif
endfunction

" Sending rpc call to erlang session
function! s:send_rpc(module, fun, args)
    call s:Log("send rpc")
    let command = "erl_call -name " . s:erlangServerName . " -a '" . a:module . " " . a:fun . " " . a:args . "'"
    let result = system(command)
    if match(result, 'erl_call: failed to connect to node .*') != -1
        call StartWranglerServer()
        let result2 = system(command)
        call s:Log("rpc result" .  result2)
        return result2
    endif
    call s:Log("rpc result" .  result)
    return result
endfunction

function! s:ErlangUndo()
    call s:send_rpc("wrangler_undo_server", "undo", "[]")
    " how to get back to the old file for module rename???
    if !empty(glob(expand("%")))
        :e!
    else
        let cur_buf = bufname("%")
        let last_buf = bufname("#")
        if exists("s:last_old_file")
            exec ':e '.s:last_old_file
        elseif last_buf != cur_buf
            "no last old file is found, but next buffer exists,jump to it
            :bn
        else
            "ok, nothing is found, create a new one
            :enew!
        endif
        "delete current buffer
        exec ':bd ' . cur_buf
    endif
endfunction

function! s:trim(text)
    return substitute(a:text, "^\\s\\+\\|\\s\\+$", "", "g")
endfunction

function! s:get_msg(result, tuple_start)
    let msg_begin = '{' . a:tuple_start . ','
    let matching_start =  match(a:result, msg_begin)
    if matching_start != -1
        return s:trim(matchstr(a:result, '[^}]*', matching_start + strlen(msg_begin)))
    endif
    return ""
endfunction

" Check if there is an error in result
function! s:check_for_error(result)
    let msg = s:get_msg(a:result, 'ok')
    if msg != ""
        return [0, msg]
    endif
    let msg = s:get_msg(a:result, 'warning')
    if msg != ""
        return [1, msg]
    endif
    let msg = s:get_msg(a:result, 'error')
    if msg != ""
        call s:Log(msg)
        return [2, msg]
    endif
    return [-1, a:result]
endfunction

" Sending apply changes to file
function! s:send_confirm(msg, old_filename, new_filename)
    let changed_files_str = matchstr(a:msg, "[^]]*", 1)
    let changed_files = substitute(changed_files_str , ',', ' ', 'g')
    echo "These files will be changed: " . changed_files_str
    let choice = confirm("What do you want?", "&Preview\n&Confirm\n&Abort", 0)
    if choice == 1
        let diff_command = s:diff_script.' '.changed_files
        let diff_output = system(diff_command)
        execute ":vsp"
        execute ":e .Erlang_Prevew_File"
        set buftype=nofile
        let lines = split(diff_output, '\n')
        let counter = 0
        for one_line in lines
            call append(counter, one_line)
            let counter = counter + 1
        endfor
        let b:msg = a:msg
        let b:old_filename = a:old_filename
        let b:new_filename = a:new_filename
        au BufLeave <buffer> :call <SID>send_confirm_from_preview()
        return 0
    endif
    if choice == 2
        let module = 'wrangler_preview_server'
        let fun = 'commit'
        let args = '[]'
        call s:send_rpc(module, fun, args)
        call s:clean_up_fun(a:msg, a:old_filename, a:new_filename)
    else
        let module = 'wrangler_preview_server'
        let fun = 'abort'
        let args = '[]'
        call s:send_rpc(module, fun, args)
    endif
    return choice
endfunction

function! s:send_confirm_from_preview()
    let a:msg = b:msg
    let a:old_filename = b:old_filename
    let a:new_filename = b:new_filename
    execute ":bd"
    call s:send_confirm(a:msg, a:old_filename, a:new_filename)
endfunction

function! s:clean_up_fun(msg, old_file, new_file)
    let s:last_old_file = a:old_file
    let changed_files_str = matchstr(a:msg, "[^]]*", 1)
    let changed_files = substitute(changed_files_str , ',', ' ', 'g')
    if a:new_file != ""
        execute ':bd ' . a:old_file 
        execute ':e! ' . a:new_file
        "this is a tricky fix for mod rename backed from preview mode
        set filetype=erlang
        execute ':silent! rm ' .a:old_file 
    else
        execute ':e! ' . a:old_file
    endif
    let clean_command = s:clean_script.' '.changed_files
    call system(clean_command)
endfunction

" Format and send function extracton call
function! s:call_extract(start_line, start_col, end_line, end_col, name)
    let file = expand("%:p")
    let module = 'wrangler_refacs'
    let fun = 'fun_extraction'
    let args = '["' . file . '", [' . a:start_line . ', ' . a:start_col . '], [' . a:end_line . ', ' . a:end_col . '], "' . a:name . '", emacs, ' . &sw . ']'
    let result = s:send_rpc(module, fun, args)
    let [error_code, msg] = s:check_for_error(result)
    if error_code != 0
        call confirm("error_cod:".error_cod."\nmsg:".msg)
        call s:Log("confirmed")
        return 0
    endif
    let old_filename = expand("%")
    let new_filename = expand("%")
    call s:send_confirm(msg, old_filename, new_filename)
    return 1
endfunction

function! s:ErlangExtractFunction(mode) range
    silent w!
    let name = inputdialog("New function name: ")
    if name != ""
        if a:mode == "v"
            let start_pos = getpos("'<")
            let start_line = start_pos[1]
            let start_col = start_pos[2]

            let end_pos = getpos("'>")
            let end_line = end_pos[1]
            let end_col = end_pos[2]
        elseif a:mode == "n"
            let pos = getpos(".")
            let start_line = pos[1]
            let start_col = pos[2]
            let end_line = pos[1]
            let end_col = pos[2]
        else
            echo "Mode not supported."
            return
        endif
        if s:call_extract(start_line, start_col, end_line, end_col, name)
            let temp = &autoread
            set autoread
            :e
            if temp == 0
                set noautoread
            endif
        endif
    else
        echo "Empty function name. Ignoring."
    endif
endfunction

function! s:call_rename(mode, line, col, name, search_path)
    let file = expand("%:p")
    let module = 'wrangler_refacs'
    let fun = 'rename_' . a:mode
    let args = '["' . file .'", '
    let old_filename = expand("%")
    if a:mode != "mod"
        let new_filename = ""
        let args = args . a:line . ', ' . a:col . ', '
    else
        let new_filename = expand("%:h") . '/' . a:name . '.erl'
    endif
    let args = args . '"' . a:name . '", [' . a:search_path . '], emacs,' . &sw . ']'
    let result = s:send_rpc(module, fun, args)
    let [error_code, msg] = s:check_for_error(result)
    if error_code != 0
        call confirm("error_code:".error_code."error happened:".msg)
        call s:Log("return after confirm")
        return 0
    endif
    return s:send_confirm(msg, old_filename, new_filename)
endfunction

function! s:GetOTPSearchPath()
    let cur_path = getcwd()
    let ret0 = []
    let ret1 = s:GetOTPSearchPathHelper(ret0, cur_path.'/src')
    let ret2 = s:GetOTPSearchPathHelper(ret1, cur_path.'/test')
    let ret3 = s:GetOTPSearchPathHelper(ret2, cur_path.'/include')

    let ret4 = ret3
    if exists("g:refactor_search_path")
        for path in ret4
            let ret4 = s:GetOTPSearchPathHelper(ret4, path)
        endfor
    endif

    return join(ret4, ",")
endfunction

function! s:GetOTPSearchPathHelper(list, path)
    if isdirectory(a:path) 
        return add(a:list, '"'.a:path.'"') 
    else
        return a:list
    endif
endfunction

function! s:ErlangRename(mode)
    silent w!
    if a:mode == "mod"
        let name = inputdialog('Rename module to: ')
    else
        let name = inputdialog('Rename "' . expand("<cword>") . '" to: ')
    endif
    if name != ""
        let search_path = s:GetOTPSearchPath()

        let pos = getpos(".")
        let line = pos[1]
        let col = pos[2]
        let current_filename = expand("%")
        let current_filepath = expand("%:p")
        call s:call_rename(a:mode, line, col, name, search_path)
    else
        echo "Empty name. Ignoring."
    endif
    call s:Log("rename success")
endfunction

function! s:ErlangRenameFunction()
    call s:ErlangRename("fun")
endfunction


function! s:ErlangRenameVariable()
    call s:ErlangRename("var")
endfunction

function! s:ErlangRenameModule()
    call s:ErlangRename("mod")
endfunction

function! s:ErlangRenameProcess()
    call s:ErlangRename("process")
endfunction

function! s:call_tuple_fun_args(start_line, start_col, end_line, end_col, search_path)
    let filename = expand("%:p")
    let module = 'wrangler_refacs'
    let fun = 'tuple_funpar'
    call s:Log("search path is:".a:search_path)
    let args = '["' . filename . '", [' . a:start_line . ', ' . a:start_col . '], [' . a:end_line . ', ' . a:end_col . '], [' . a:search_path . '], emacs ' . &sw . ']'
    let result = s:send_rpc(module, fun, args)
    let [error_code, msg] = s:check_for_error(result)
    if error_code != 0
        return 0
    endif
    let old_filename = expand("%")
    let new_filename = expand("%")
    call s:send_confirm(msg, old_filename, new_filename)
    return 1
endfunction

function! s:ErlangTupleFunArgs(mode)
    silent w!
    let search_path = s:GetOTPSearchPath()
    if a:mode == "v"
        let start_pos = getpos("'<")
        let start_line = start_pos[1]
        let start_col = start_pos[2]

        let end_pos = getpos("'>")
        let end_line = end_pos[1]
        let end_col = end_pos[2]
        call s:call_tuple_fun_args(start_line, start_col, end_line, end_col, search_path)
    elseif a:mode == "n"
        let pos = getpos(".")
        let line = pos[1]
        let col = pos[2]
        call s:call_tuple_fun_args(line, col, line, col, search_path)
    else
        echo "Mode not supported."
    endif
endfunction

""all mappings are here
nmap <leader>au :call <SID>ErlangUndo()<CR>
nmap <leader>at :call <SID>ErlangTupleFunArgs("n")<CR>
vmap <leader>at :call <SID>ErlangTupleFunArgs("v")<CR>
nmap <leader>ae :call <SID>ErlangExtractFunction("n")<CR>
vmap <leader>ae :call <SID>ErlangExtractFunction("v")<CR>
map <leader>af :call <SID>ErlangRenameFunction()<CR>
map <leader>av :call <SID>ErlangRenameVariable()<CR>
map <leader>am :call <SID>ErlangRenameModule()<CR>
map <leader>ap :call <SID>ErlangRenameProcess()<CR>
