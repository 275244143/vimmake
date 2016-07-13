" vimmake.vim - Enhenced Customize Make system for vim
"
" Maintainer: skywind3000 (at) gmail.com
" Last change: 2016.7.7
"
" Execute customize tools: ~/.vim/vimmake.{name} directly:
"     :VimTool {name}
"
" Environment variables are set before executing:
"     $VIM_FILEPATH  - File name of current buffer with full path
"     $VIM_FILENAME  - File name of current buffer without path
"     $VIM_FILEDIR   - Full path of current buffer without the file name
"     $VIM_FILEEXT   - File extension of current buffer
"     $VIM_FILENOEXT - File name of current buffer without path and extension
"     $VIM_CWD       - Current directory
"     $VIM_RELDIR    - File path relativize to current directory
"     $VIM_RELNAME   - File name relativize to current directory 
"     $VIM_CWORD     - Current word under cursor
"     $VIM_CFILE     - Current filename under cursor
"     $VIM_GUI       - Is running under gui ?
"     $VIM_VERSION   - Value of v:version
"     $VIM_MODE      - Execute via 0:!, 1:makeprg, 2:system()
"     $VIM_SCRIPT    - Home path of tool scripts
"     $VIM_TARGET    - Target given after name as ":VimTool {name} {target}"
"     $VIM_COLUMNS   - How many columns in vim's screen
"     $VIM_LINES     - How many lines in vim's screen
"
" Settings:
"     g:vimmake_path - change the path of tools rather than ~/.vim/
"     g:vimmake_mode - dictionary of invoke mode of each tool
" 
" Setup mode for command: ~/.vim/vimmake.{name}
"     let g:vimmake_mode["name"] = "{mode}" 
"     {mode} can be: 
"		"normal"	- launch the tool and return to vim after exit (default)
"		"quickfix"	- launch and redirect output to quickfix
"		"bg"		- launch background and discard any output
"		"async"		- run in async mode and redirect output to quickfix
"	  
"	  note: "g:vimmake_mode" must be initialized to "{}" at first
" 
" Emake can be installed to /usr/local/bin to build C/C++ by: 
"     $ wget https://skywind3000.github.io/emake/emake.py
"     $ sudo python emake.py -i
"
"


"----------------------------------------------------------------------
"- Global Variables
"----------------------------------------------------------------------

" default tool location is ~/.vim which could be changed by g:vimmake_path
if !exists("g:vimmake_path")
	let g:vimmake_path = "~/.vim"
endif

" don't save file by default
if !exists("g:vimmake_save")
	let g:vimmake_save = 0
endif

" default cc executable
if !exists("g:vimmake_cc")
	let g:vimmake_cc = "gcc"
endif

" default gcc cflags
if !exists("g:vimmake_cflags")
	let g:vimmake_cflags = []
endif

" default modes
if !exists("g:vimmake_mode")
	let g:vimmake_mode = {}
endif

" error format
if !exists("g:vimmake_match")
	let g:vimmake_match = {}
endif

" single error format
if !exists("g:vimmake_error")
	let g:vimmake_error = "%f:%l:%m"
endif

" change directory to %:p:h before running
if !exists("g:vimmake_cwd")
	let g:vimmake_cwd = 0
endif

" using timer to update quickfix
if !exists('g:vimmake_build_timer')
	let g:vimmake_build_timer = 0
endif

" will be executed after async build finished
if !exists('g:vimmake_build_post')
	let g:vimmake_build_post = ''
endif

" will be executed after output callback
if !exists('g:vimmake_build_update')
	let g:vimmake_build_update = ''
endif

" signal to stop job
if !exists('g:vimmake_build_stop')
	let g:vimmake_build_stop = 'term'
endif

" build status
if !exists('g:vimmake_build_status')
	let g:vimmake_build_status = ''
endif

" auto scroll quickfix
if !exists('g:vimmake_build_scroll')
	let g:vimmake_build_scroll = 0
endif

" external runner
if !exists('g:vimmake_runner')
	let g:vimmake_runner = ''
endif

" main run
if !exists('g:vimmake_run_guess')
	let g:vimmake_run_guess = []
endif

" extname -> command
if !exists('g:vimmake_extrun')
	let g:vimmake_extrun = {}
endif


"----------------------------------------------------------------------
" Internal Definition
"----------------------------------------------------------------------

" path where vimmake.vim locates
let s:vimmake_home = fnamemodify(resolve(expand('<sfile>:p')), ':h')
let g:vimmake_home = s:vimmake_home
let s:vimmake_advance = 0	" internal usage, won't be modified by user
let g:vimmake_advance = 0	" external reference, may be modified by user
let s:vimmake_windows = 0	" internal usage, won't be modified by user
let g:vimmake_windows = 0	" external reference, may be modified by user

" check has advanced mode
if v:version >= 800 || has('patch-7.4.1829')
	if has('job') && has('channel') && has('timers') && has('reltime') 
		let s:vimmake_advance = 1
		let g:vimmake_advance = 1
	endif
endif

" check running in windows
if has('win32') || has('win64') || has('win95') || has('win16')
	let s:vimmake_windows = 1
	let g:vimmake_windows = 1
endif

" backup local makeprg and errorformat
function! s:MakeSave()
	let s:make_save = &l:makeprg
	let s:match_save = &l:errorformat
endfunc

" restore local makeprg and errorformat
function! s:MakeRestore()
	let &l:makeprg = s:make_save
	let &l:errorformat = s:match_save
endfunc

" init current working directory
function! s:CwdInit(force)
	if has('s:cwd_save')
		if s:cwd_save != "" | return | endif
	endif
	let s:cwd_save = getcwd()
	let s:cwd_local = haslocaldir()
	let l:cwd = expand("%:p:h")
	if (g:vimmake_cwd != 0 || a:force != 0) && expand("%:p") != ""
		if s:cwd_local == 0
			silent exec 'cd ' . fnameescape(l:cwd)
		else
			silent exec 'lcd ' . fnameescape(l:cwd)
		endif
	endif
endfunc

" restore current working directory
function! s:CwdRestore(force)
	if exists('s:cwd_save') && exists('s:cwd_local')
		if (g:vimmake_cwd != 0 || a:force != 0) && s:cwd_save != "" 
			if s:cwd_local == 0
				silent exec 'cd '. fnameescape(s:cwd_save)
			else
				silent exec 'lcd '. fnameescape(s:cwd_save)
			endif
		endif
		let s:cwd_save = ""
		unlet s:cwd_save
	endif
endfunc

" join two path
function! s:PathJoin(home, name)
    let l:size = strlen(a:home)
    if l:size == 0 | return a:name | endif
    let l:last = strpart(a:home, l:size - 1, 1)
    if has("win32") || has("win64") || has("win16") || has('win95')
        if l:last == "/" || l:last == "\\"
            return a:home . a:name
        else
            return a:home . '/' . a:name
        endif
    else
        if l:last == "/"
            return a:home . a:name
        else
            return a:home . '/' . a:name
        endif
    endif
endfunc

" save file
function! s:CheckSave()
	if bufname('%') == '' || getbufvar('%', '&modifiable') == 0
		return
	endif
	if g:vimmake_save == 1
		silent exec "update"
	elseif g:vimmake_save == 2
		silent exec "wa"
	endif
endfunc

" error message
function! s:ErrorMsg(msg)
	echohl ErrorMsg
	echom 'ERROR: '. a:msg
	echohl NONE
endfunc

" show not support message
function! s:NotSupport()
	let l:msg = "required: +timers +channel +job +reltime and vim >= 7.4.1829"
	call s:ErrorMsg(l:msg)
endfunc


"----------------------------------------------------------------------
"- Execute Files
"----------------------------------------------------------------------
function! Vimmake_Execute(mode)
	if a:mode == 0		" Execute current filename
		let l:fname = shellescape(expand("%:p"))
		if has('gui_running') && (s:vimmake_windows != 0)
			silent exec '!start cmd /C '. l:fname .' & pause'
		else
			exec '!' . l:fname
		endif
	elseif a:mode == 1	" Execute current filename without extname
		let l:fname = shellescape(expand("%:p:r"))
		if has('gui_running') && (s:vimmake_windows != 0)
			silent exec '!start cmd /C '. l:fname .' & pause'
		else
			exec '!' . l:fname
		endif
	elseif a:mode == 2
		let l:fname = shellescape(expand("%"))
		if has('gui_running') && (s:vimmake_windows != 0)
			silent exec '!start cmd /C emake -e '. l:fname .' & pause'
		else
			exec '!emake -e ' . l:fname
		endif
	else
	endif
endfunc


"----------------------------------------------------------------------
"- Execute command in normal(0), quickfix(1), system(2) mode
"----------------------------------------------------------------------
function! Vimmake_Command(command, target, mode, match)
	let $VIM_FILEPATH = expand("%:p")
	let $VIM_FILENAME = expand("%:t")
	let $VIM_FILEDIR = expand("%:p:h")
	let $VIM_FILENOEXT = expand("%:t:r")
	let $VIM_FILEEXT = "." . expand("%:e")
	let $VIM_CWD = expand("%:p:h:h")
	let $VIM_RELDIR = expand("%:h")
	let $VIM_RELNAME = expand("%:p:.")
	let $VIM_CWORD = expand("<cword>")
	let $VIM_CFILE = expand("<cfile>")
	let $VIM_VERSION = ''.v:version
	let $VIM_MODE = ''. a:mode
	let $VIM_GUI = '0'
	let $VIM_SCRIPT = g:vimmake_path
	let $VIM_SVRNAME = v:servername
	let $VIM_TARGET = a:target
	let $VIM_COLUMNS = &columns
	let $VIM_LINES = &lines
	let l:text = ''
	if has("gui_running")
		let $VIM_GUI = '1'
	endif
	let l:cmd = shellescape(a:command)
	if (a:mode == 0) || ((!has("quickfix")) && a:mode == 1)
		if has('gui_running') && (s:vimmake_windows != 0)
			silent exec '!start cmd /c '. l:cmd . ' & pause'
		else
			exec '!' . l:cmd
		endif
	elseif (a:mode == 1)
		call s:MakeSave()
		if a:match == ''
			let &l:errorformat=g:vimmake_error
		else
			let &l:errorformat=a:match
		endif
		let &l:makeprg = a:command
		exec "make!"
		call s:MakeRestore()
	elseif (a:mode == 2)
		let l:text = system("" . l:cmd)
	elseif (a:mode == 3)
		if s:vimmake_windows != 0
			silent exec '!start /b cmd.exe /C '. l:cmd
		else
			call system("". l:cmd . ' &')
		endif
	elseif (a:mode == 4)
		if s:vimmake_windows != 0
			silent exec '!start /min cmd.exe /C '. l:cmd . ' & pause'
		else
			exec '!' . l:cmd
		endif
	elseif (a:mode == 5)
		if has('python')
			python import vim, subprocess
			python x = [vim.eval('a:command')]
			python m = subprocess.PIPE
			python n = subprocess.STDOUT
			python s = sys.platform[:3] == 'win' and True or False
			python p = subprocess.Popen(x, shell = s, stdout = m, stderr = n)
			python t = p.stdout.read()
			python p.stdout.close()
			python p.wait()
			python t = t.replace('\\', '\\\\').replace('"', '\\"')
			python t = t.replace('\n', '\\n').replace('\r', '\\r')
			python vim.command('let l:text = "%s"'%t)
		else
			echohl ErrorMsg
			echom "ERROR: This vim version does not support python"
			echohl NONE
		endif
	elseif (a:mode == 6)
		if s:vimmake_advance == 0
			call s:NotSupport()
		else
			call g:Vimmake_Build_Start(a:command)
		endif
	elseif (a:mode == 7)
		if g:vimmake_runner != ''
			call call(g:vimmake_runner, [a:command])
		else
			echohl ErrorMsg
			echom "ERROR: g:vimmake_runner is empty"
			echohl NONE
		endif
	endif
	return l:text
endfunc


"----------------------------------------------------------------------
"- build in background
"----------------------------------------------------------------------
let s:build_output = {}
let s:build_head = 0
let s:build_tail = 0
let s:build_code = 0
let s:build_state = 0
let s:build_start = 0.0
let s:build_debug = 0
let s:build_quick = 0

" check :cbottom available
if has('patch-7.4.1997')
	let s:build_quick = 1
endif

" scroll quickfix down
function! s:Vimmake_Build_Scroll()
	if getbufvar('%', '&buftype') == 'quickfix'
		silent normal G
	endif
endfunc

" find quickfix window and scroll to the bottom then return last window
function! s:Vimmake_Build_AutoScroll()
	if s:build_quick == 0
		let l:winnr = winnr()			
		windo call s:Vimmake_Build_Scroll()
		silent exec ''.l:winnr.'wincmd w'
	else
		cbottom
	endif
endfunc

" invoked on timer or finished
function! s:Vimmake_Build_Update(count)
	let l:count = 0
	while s:build_tail < s:build_head
		let l:text = s:build_output[s:build_tail]
		if l:text != '' 
			caddexpr l:text
		endif
		unlet s:build_output[s:build_tail]
		let s:build_tail += 1
		let l:count += 1
		if a:count > 0 && l:count >= a:count
			break
		endif
	endwhile
	if and(g:vimmake_build_scroll, 1) != 0
		call s:Vimmake_Build_AutoScroll()
	endif
	if and(g:vimmake_build_scroll, 8) != 0
		silent clast
	endif
	if g:vimmake_build_update != ''
		exec g:vimmake_build_update
	endif
	return l:count
endfunc

" invoked on timer
function! g:Vimmake_Build_OnTimer(id)
	if exists('s:build_job')
		call job_status(s:build_job)
	endif
	call s:Vimmake_Build_Update(5 + g:vimmake_build_timer)
endfunc

" invoked on "callback" when job output
function! g:Vimmake_Build_OnCallback(channel, text)
	if !exists("s:build_job")
		return
	endif
	if type(a:text) != 1
		return
	endif
	if a:text == ''
		return
	endif
	let s:build_output[s:build_head] = a:text
	let s:build_head += 1
	if g:vimmake_build_timer <= 0
		call s:Vimmake_Build_Update(-1)
	endif
endfunc

" because exit_cb and close_cb are disorder, we need OnFinish to guarantee
" both of then have already invoked
function! s:Vimmake_Build_OnFinish(what)
	" caddexpr '(OnFinish): '.a:what.' '.s:build_state
	if s:build_state == 0
		return -1
	endif
	if a:what == 0
		let s:build_state = or(s:build_state, 2)
	else
		let s:build_state = or(s:build_state, 4)
	endif
	if and(s:build_state, 7) != 7
		return -2
	endif
	if exists('s:build_job')
		unlet s:build_job
	endif
	if exists('s:build_timer')
		call timer_stop(s:build_timer)
		unlet s:build_timer
	endif
	call s:Vimmake_Build_Update(-1)
	let l:current = float2nr(reltimefloat(reltime()))
	let l:last = l:current - s:build_start
	if s:build_code == 0
		caddexpr "[Finished in ".l:last." seconds]"
		let g:vimmake_build_status = "success"
	else
		let l:text = 'with code '.s:build_code
		caddexpr "[Finished in ".l:last." seconds ".l:text."]"
		let g:vimmake_build_status = "failure"
	endif
	let s:build_state = 0
	if and(g:vimmake_build_scroll, 1) != 0
		call s:Vimmake_Build_AutoScroll()
	endif
	if and(g:vimmake_build_scroll, 4) != 0
		silent clast
	endif
	redrawstatus!
	redraw
	if g:vimmake_build_post != ""
		exec g:vimmake_build_post
	endif
endfunc

" invoked on "close_cb" when channel closed
function! g:Vimmake_Build_OnClose(channel)
	" caddexpr "[close]"
	let s:build_debug = 1
	let l:limit = 512
	while ch_status(a:channel) == 'buffered'
		let l:text = ch_read(a:channel)
		if l:text == '' " important when child process is killed
			let l:limit -= 1
			if l:limit < 0 | break | endif
		endif
		call g:Vimmake_Build_OnCallback(a:channel, l:text)
	endwhile
	let s:build_debug = 0
	call s:Vimmake_Build_Update(-1)
	call s:Vimmake_Build_OnFinish(1)
	if exists('s:build_job')
		call job_status(s:build_job)
	endif
endfunc

" invoked on "exit_cb" when job exited
function! g:Vimmake_Build_OnExit(job, message)
	" caddexpr "[exit]: ".a:message." ".type(a:message)
	let s:build_code = a:message
	call s:Vimmake_Build_OnFinish(0)
endfunc

" start background build
function! g:Vimmake_Build_Start(cmd)
	let l:running = 0
	let l:empty = 0
	if s:vimmake_advance == 0
		call s:NotSupport()
		return -1
	endif
	if exists('s:build_job')
		if job_status(s:build_job) == 'run'
			let l:running = 1
		endif
	endif
	if type(a:cmd) == 1
		if a:cmd == '' | let l:empty = 1 | endif
	elseif type(a:cmd) == 3
		if a:cmd == [] | let l:empty = 1 | endif
	endif
	if s:build_state != 0 || l:running != 0
		call s:ErrorMsg("background job is still running")
		return -2
	elseif l:empty == 0
		let l:args = []
		let l:name = []
		if has('win32') || has('win64') || has('win16') || has('win95')
			let l:args = ['cmd.exe', '/C']
		else
			let l:args = ['/bin/sh', '-c']
		endif
		if type(a:cmd) == 1
			let l:args += [a:cmd]
			let l:name = a:cmd
		elseif type(a:cmd) == 3
			if s:vimmake_windows == 0
				let l:temp = []
				for l:item in a:cmd
					let l:temp += [fnameescape(l:item)]
				endfor
				let l:args += [join(l:temp, ' ')]
			else
				let l:args += a:cmd
			endif
			let l:vector = []
			for l:x in a:cmd
				let l:vector += ['"'.l:x.'"']
			endfor
			let l:name = join(l:vector, ', ')
		endif
		let l:options = {}
		let l:options['callback'] = 'g:Vimmake_Build_OnCallback'
		let l:options['close_cb'] = 'g:Vimmake_Build_OnClose'
		let l:options['exit_cb'] = 'g:Vimmake_Build_OnExit'
		let l:options['out_io'] = 'pipe'
		let l:options['err_io'] = 'out'
		let l:options['out_mode'] = 'nl'
		let l:options['err_mode'] = 'nl'
		let l:options['stoponexit'] = 'term'
		if g:vimmake_build_stop != ''
			let l:options['stoponexit'] = g:vimmake_build_stop
		endif
		let s:build_job = job_start(l:args, l:options)
		if job_status(s:build_job) != 'fail'
			let s:build_output = {}
			let s:build_head = 0
			let s:build_tail = 0
			if type(a:cmd) == 1
				exec "cexpr \'[".fnameescape(l:name)."]\'"
			else
				let l:arguments = l:name
				exec "cexpr \'[\'.l:arguments.\']\'"
			endif
			let s:build_start = float2nr(reltimefloat(reltime()))
			if g:vimmake_build_timer > 0
				let l:options = {'repeat':-1}
				let l:name = 'g:Vimmake_Build_OnTimer'
				let s:build_timer = timer_start(1000, l:name, l:options)
			endif
			let s:build_state = 1
			let g:vimmake_build_status = "running"
			redrawstatus!
		else
			unlet s:build_job
			call s:ErrorMsg("Background job start failed '".a:cmd."'")
			return -3
		endif
	else
		echo "empty cmd"
		return -4
	endif
	return 0
endfunc

" stop background job
function! g:Vimmake_Build_Stop(how)
	let l:how = a:how
	if s:vimmake_advance == 0
		call s:NotSupport()
		return -1
	endif
	if l:how == '' | let l:how = 'term' | endif
	if exists('s:build_job')
		if job_status(s:build_job) == 'run'
			call job_stop(s:build_job, l:how)
		else
			return -2
		endif
	else
		return -3
	endif
	return 0
endfunc

" get job status
function! g:Vimmake_Build_Status()
	if exists('s:build_job')
		return job_status(s:build_job)
	else
		return 'none'
	endif
endfunc


"----------------------------------------------------------------------
"- Execute ~/.vim/vimmake.{command}
"----------------------------------------------------------------------
function! s:Cmd_VimTool(bang, ...)
	if a:0 == 0
		echohl ErrorMsg
		echom "E471: Argument required"
		echohl NONE
		return
	endif
	let l:command = a:1
	let l:target = ''
	if a:0 >= 2
		let l:target = a:2
	endif
	let l:home = expand(g:vimmake_path)
	let l:fullname = "vimmake." . l:command
	let l:fullname = s:PathJoin(l:home, l:fullname)
	let l:value = get(g:vimmake_mode, l:command, '')
	let l:match = get(g:vimmake_match, l:command, '')
	if a:bang != '!'
		silent call s:CheckSave()
	endif
	if type(l:value) == 0 
		let l:mode = string(l:value) 
	else
		let l:mode = l:value
	endif
	if l:match == ''
		let l:match = g:vimmake_error
	endif
	if index(['', '0', 'normal', 'default'], l:mode) >= 0
		call Vimmake_Command(l:fullname, l:target, 0, l:match)
	elseif index(['1', 'quickfix', 'make', 'makeprg'], l:mode) >= 0
		call Vimmake_Command(l:fullname, l:target, 1, l:match)
	elseif index(['2', 'system', 'silent'], l:mode) >= 0
		call Vimmake_Command(l:fullname, l:target, 2, l:match)
	elseif index(['3', 'background', 'bg'], l:mode) >= 0
		call Vimmake_Command(l:fullname, l:target, 3, l:match)
	elseif index(['4', 'minimal', 'm', 'min'], l:mode) >= 0
		call Vimmake_Command(l:fullname, l:target, 4, l:match)
	elseif index(['5', 'python', 'p', 'py'], l:mode) >= 0
		call Vimmake_Command(l:fullname, l:target, 5, l:match)
	elseif index(['6', 'async', 'job', 'channel'], l:mode) >= 0
		call Vimmake_Command(l:fullname, l:target, 6, l:match)
	elseif index(['7', 'runner', 'extern'], l:mode) >= 0
		call Vimmake_Command(l:fullname, l:target, 7, l:match)
	else
		call s:ErrorMsg("invalid mode: ".l:mode)
	endif
	return l:fullname
endfunc

function! s:Cmd_VimStop(bang)
	if a:bang == ''
		call g:Vimmake_Build_Stop('term')
	else
		call g:Vimmake_Build_Stop('kill')
	endif
endfunc


" command definition
command! -bang -nargs=* VimTool call s:Cmd_VimTool('<bang>', <f-args>)
command! -bang -nargs=0 VimStop call s:Cmd_VimStop('<bang>')


"----------------------------------------------------------------------
"- Execute current file by mode or filetype
"----------------------------------------------------------------------
function! s:Cmd_VimExecute(bang, ...)
	let l:mode = ''
	let l:cwd = 0
	if a:0 >= 1
		let l:mode = a:1
	endif
	if a:0 >= 2
		if index(['1', 'true', 'True', 'yes', 'cwd', 'cd'], a:2) >= 0 
			let l:cwd = 1 
		endif
	endif
	if a:bang != '!'
		silent call s:CheckSave()
	endif
	if bufname('%') == '' | return | endif
	let l:ext = expand("%:e")
	call s:CwdInit(l:cwd)
	if index(['', '0', 'file', 'filename'], l:mode) >= 0
		call Vimmake_Execute(0)
	elseif index(['1', 'main', 'mainname', 'noext', 'exe'], l:mode) >= 0
		call Vimmake_Execute(1)
	elseif index(['2', 'emake'], l:mode) >= 0
		call Vimmake_Execute(2)
	elseif index(['c', 'cpp', 'cc', 'm', 'mm', 'cxx'], l:ext) >= 0
		call Vimmake_Execute(1)
	elseif index(['h', 'hh', 'hpp'], l:ext) >= 0
		call Vimmake_Execute(1)
	elseif index(g:vimmake_run_guess, l:ext) >= 0
		call Vimmake_Execute(1)
	elseif index(['mak', 'emake'], l:ext) >= 0
		call Vimmake_Execute(2)
	elseif &filetype == "vim"
		exec 'source ' . fnameescape(expand("%"))
	elseif has('gui_running') && (s:vimmake_windows != 0)
		let l:cmd = get(g:vimmake_extrun, l:ext, '')
		let l:fname = shellescape(expand("%"))
		if l:cmd != ''
			silent exec '!start cmd /C '. l:cmd . ' ' . l:fname . ' & pause'
		elseif index(['py', 'pyw', 'pyc', 'pyo'], l:ext) >= 0
			silent exec '!start cmd /C python ' . l:fname . ' & pause'
		elseif l:ext  == "js"
			silent exec '!start cmd /C node ' . l:fname . ' & pause'
		elseif l:ext == 'sh'
			silent exec '!start cmd /C sh ' . l:fname . ' & pause'
		elseif l:ext == 'lua'
			silent exec '!start cmd /C lua ' . l:fname . ' & pause'
		elseif l:ext == 'pl'
			silent exec '!start cmd /C perl ' . l:fname . ' & pause'
		elseif l:ext == 'rb'
			silent exec '!start cmd /C ruby ' . l:fname . ' & pause'
		elseif l:ext == 'php'
			silent exec '!start cmd /C php ' . l:fname . ' & pause'
		elseif index(['osa', 'scpt', 'applescript'], l:ext) >= 0
			silent exec '!start cmd /C osascript '.l:fname.' & pause'
		else
			call Vimmake_Execute(0)
		endif
	else
		let l:cmd = get(g:vimmake_extrun, l:ext, '')
		if l:cmd != ''
			exec '!'. l:cmd . ' ' . shellescape(expand("%"))
		elseif index(['py', 'pyw', 'pyc', 'pyo'], l:ext) >= 0
			exec '!python ' . shellescape(expand("%"))
		elseif l:ext  == "js"
			exec '!node ' . shellescape(expand("%"))
		elseif l:ext == 'sh'
			exec '!sh ' . shellescape(expand("%"))
		elseif l:ext == 'lua'
			exec '!lua ' . shellescape(expand("%"))
		elseif l:ext == 'pl'
			exec '!perl ' . shellescape(expand("%"))
		elseif l:ext == 'rb'
			exec '!ruby ' . shellescape(expand("%"))
		elseif l:ext == 'php'
			exec '!php ' . shellescape(expand("%"))
		elseif index(['osa', 'scpt', 'applescript'], l:ext) >= 0
			exec '!osascript '. shellescape(expand('%'))
		else
			call Vimmake_Execute(0)
		endif
	endif
	call s:CwdRestore(l:cwd)
endfunc


" command definition
command! -bang -nargs=* VimExecute call s:Cmd_VimExecute('<bang>', <f-args>)
command! -bang -nargs=? VimRun call s:Cmd_VimExecute('<bang>', '?', <f-args>)


"----------------------------------------------------------------------
"- make via gcc
"----------------------------------------------------------------------
function! Vimmake_Make_Gcc(filename, mode)
	let l:source = shellescape(a:filename)
	let l:output = shellescape(fnamemodify(a:filename, ':r'))
	let l:cc = 'gcc'
	if g:vimmake_cc != ''
		let l:cc = g:vimmake_cc
	endif
	let l:flags = join(g:vimmake_cflags, ' ')
	let l:extname = expand("%:e")
	if index(['cpp', 'cc', 'cxx', 'mm'], l:extname) >= 0
		let l:flags .= ' -lstdc++'
	endif
	if a:mode == 0 && has('quickfix')
		call s:MakeSave()
		let l:cmd = l:cc . ' -Wall '. l:source . ' -o ' . l:output
		let &l:makeprg = l:cmd . ' ' . l:flags
		let &l:errorformat = '%f:%l:%m'
		exec 'make!'
		call s:MakeRestore()
	elseif a:mode == 0 || a:mode == 1
		let l:cmd = l:cc . ' -Wall '. l:source . ' -o ' . l:output
		if s:vimmake_windows == 0
			exec '!'.l:cmd . ' ' . l:flags
		else
			exec '!start cmd.exe /C '.l:cmd. ' '.l:flags.' & pause'
		endif
	elseif a:mode == 2
		let l:output = fnamemodify(a:filename, ':r')
		let l:cmd = [l:cc, '-Wall', a:filename, '-o', l:output]
		let l:cmd += g:vimmake_cflags
		if index(['cpp', 'cc', 'cxx', 'mm'], l:extname) >= 0
			let l:cmd += ['-lstdc++']
		endif
		call Vimmake_Build_Start(l:cmd)
	endif
endfunc


"----------------------------------------------------------------------
"- make via emake (http://skywind3000.github.io/emake/emake.py)
"----------------------------------------------------------------------
function! Vimmake_Make_Emake(filename, mode, ininame)
	let l:source = shellescape(a:filename)
	let l:config = shellescape(a:ininame)
	if a:mode == 0 && has('quickfix')
		call s:MakeSave()
		let &l:errorformat='%f:%l:%m'
		if a:ininame == ''
			let &l:makeprg = 'emake '. l:source
			exec "make!"
		else
			let &l:makeprg = 'emake --ini='. l:config . ' '. l:source
			exec "make!"
		endif
		call s:MakeRestore()
	elseif a:mode == 0 || a:mode == 1
		if s:vimmake_windows == 0
			if a:ininame == ''
				exec '!emake ' . l:source
			else
				exec '!emake "--ini=' . l:config . '" ' . l:source
			endif
		else
			if a:ininame == ''
				silent exec '!start cmd.exe /C emake '. l:source .' & pause'
			else
				let l:cmd = 'emake --ini='. l:config . ' ' . l:source
				silent exec '!start cmd.exe /C '. l:cmd .' & pause'
			endif
		endif
	elseif a:mode == 2
		if a:ininame == ''
			call g:Vimmake_Build_Start(['emake', a:filename])
		else
			let l:cfg = '--ini=' . a:ininame
			call g:Vimmake_Build_Start(['emake', l:cfg, a:filename])
		endif
	endif
endfunc


"----------------------------------------------------------------------
"- make via gnu make
"----------------------------------------------------------------------
function! Vimmake_Make_Make(target, mode)
	let l:target = shellescape(target)
	if a:mode == 0 && has('quickfix')
		call s:MakeSave()
		if a:target == ''
			let &l:makeprg = 'make'
			exec 'make!'
		else
			let &l:makeprg = 'make '.l:target
			exec 'make!'
		endif
		call s:MakeRestore()
	elseif a:mode == 0 || a:mode == 1
		if s:vimmake_windows == 0
			if a:target == ''
				exec '!make'
			else
				exec '!make '.l:target
			endif
		else
			if a:target == ''
				exec '!start cmd.exe /C make & pause'
			else
				exec '!start cmd.exe /C make '.l:target.' & pause'
			endif
		endif
	elseif a:mode == 2
		if a:target == ''
			call g:Vimmake_Build_Start(['make'])
		else
			call g:Vimmake_Build_Start(['make', a:target])
		endif
	endif
endfunc


"----------------------------------------------------------------------
"- build via gcc/make/emake
"----------------------------------------------------------------------
if !exists('g:vimmake_build_mode')
	let g:vimmake_build_mode = 0
endif

function! s:Cmd_VimMake(bang, ...)
	if bufname('%') == '' | return | endif
	if a:0 == 0
		echohl ErrorMsg
		echom "E471: Argument required"
		echohl NONE
		return
	endif
	if a:bang != '!'
		silent call s:CheckSave()
	endif
	let l:mode = 0
	let l:what = a:1
	let l:conf = ""
	if a:0 >= 2
		let l:conf = a:2
	endif
	if index(['0', 'gcc', 'cc'], l:what) >= 0
		call Vimmake_Make_Gcc(expand("%"), g:vimmake_build_mode)
	elseif index(['1', 'make'], l:what) >= 0
		call Vimmake_Make_Make(l:conf, g:vimmake_build_mode)
	elseif index(['2', 'emake'], l:what) >= 0
		call Vimmake_Make_Emake(expand("%"), g:vimmake_build_mode, l:conf)
	endif
endfunc


command! -bang -nargs=* VimMake call s:Cmd_VimMake('<bang>', <f-args>)


"----------------------------------------------------------------------
" grep code
"----------------------------------------------------------------------
let g:vimmake_grepinc = ['c', 'cpp', 'cc', 'h', 'hpp', 'hh']
let g:vimmake_grepinc += ['m', 'mm', 'py', 'js', 'php', 'java', 'vim']

function! s:Cmd_GrepCode(text)
	let l:grep = &grepprg
	if strpart(l:grep, 0, 8) == 'findstr '
		let l:inc = ''
		for l:item in g:vimmake_grepinc
			let l:inc .= '*.'.l:item.' '
		endfor
		exec 'grep! /s /C:"'. a:text . '" '. l:inc
	else
		let l:inc = ''
		for l:item in g:vimmake_grepinc
			let l:inc .= " --include \\*." . l:item
		endfor
		exec 'grep! -R ' . shellescape(a:text) . l:inc. ' *'
	endif
endfunc


command! -nargs=1 GrepCode call s:Cmd_GrepCode(<f-args>)



"----------------------------------------------------------------------
" cscope easy
"----------------------------------------------------------------------
function! s:Cmd_VimScope(what, name)
	let l:text = ''
	if a:what == '0' || a:what == 's'
		let l:text = 'symbol "'.a:name.'"'
	elseif a:what == '1' || a:what == 'g'
		let l:text = 'definition of "'.a:name.'"'
	elseif a:what == '2' || a:what == 'd'
		let l:text = 'functions called by "'.a:name.'"'
	elseif a:what == '3' || a:what == 'c'
		let l:text = 'functions calling "'.a:name.'"'
	elseif a:what == '4' || a:what == 't'
		let l:text = 'string "'.a:name.'"'
	elseif a:what == '6' || a:what == 'e'
		let l:text = 'egrep "'.a:name.'"'
	elseif a:what == '7' || a:what == 'f'
		let l:text = 'file "'.a:name.'"'
	elseif a:what == '8' || a:what == 'i'
		let l:text = 'files including "'.a:name.'"'
	elseif a:what == '9' || a:what == 'a'
		let l:text = 'assigned "'.a:name
	endif
	silent cexpr "[cscope ".a:what.": ".l:text."]"
	try
		exec 'cs find '.a:what.' '.fnameescape(a:name)
	catch /^Vim\%((\a\+)\)\=:E259/
		echohl ErrorMsg
		echo "E259: not find "'.a:name.'"'
		echohl NONE
	catch /^Vim\%((\a\+)\)\=:E567/
		echohl ErrorMsg
		echo "E567: no cscope connections"
		echohl NONE
	catch /^Vim\%((\a\+)\)\=:E/
		echohl ErrorMsg
		echo "ERROR: cscope error"
		echohl NONE
	endtry
endfunc

command! -nargs=* VimScope call s:Cmd_VimScope(<f-args>)


"----------------------------------------------------------------------
" Keymap Setup
"----------------------------------------------------------------------
function! s:Cmd_MakeKeymap()
	noremap <silent><F5> :VimExecute run<cr>
	noremap <silent><F6> :VimExecute filename<cr>
	noremap <silent><F7> :VimMake emake<cr>
	noremap <silent><F8> :VimExecute emake<cr>
	noremap <silent><F9> :VimMake gcc<cr>
	noremap <silent><F10> :call vimmake#Toggle_Quickfix()<cr>
	inoremap <silent><F5> <ESC>:VimExecute run<cr>
	inoremap <silent><F6> <ESC>:VimExecute filename<cr>
	inoremap <silent><F7> <ESC>:VimMake emake<cr>
	inoremap <silent><F8> <ESC>:VimExecute emake<cr>
	inoremap <silent><F9> <ESC>:VimMake gcc<cr>
	inoremap <silent><F10> <ESC>:call vimmake#Toggle_Quickfix()<cr>

	noremap <silent><F11> :cp<cr>
	noremap <silent><F12> :cn<cr>
	inoremap <silent><F11> <ESC>:cp<cr>
	inoremap <silent><F12> <ESC>:cn<cr>

	noremap <silent><leader>cp :cp<cr>
	noremap <silent><leader>cn :cn<cr>
	noremap <silent><leader>co :copen 6<cr>
	noremap <silent><leader>cl :cclose<cr>
	
	" set keymap to GrepCode 
	noremap <silent><leader>cr :GrepCode <C-R>=expand("<cword>")<cr><cr>

	" set keymap to cscope
	if has("cscope")
		noremap <leader>cs :VimScope s <C-R>=expand("<cword>")<CR><CR>
		noremap <leader>cg :VimScope g <C-R>=expand("<cword>")<CR><CR>
		noremap <leader>cc :VimScope c <C-R>=expand("<cword>")<CR><CR>
		noremap <leader>ct :VimScope t <C-R>=expand("<cword>")<CR><CR>
		noremap <leader>ce :VimScope e <C-R>=expand("<cword>")<CR><CR>
		noremap <leader>cf :VimScope f <C-R>=expand("<cword>")<CR><CR>
		noremap <leader>ci :VimScope i <C-R>=expand("<cword>")<CR><CR>
		noremap <leader>cd :VimScope d <C-R>=expand("<cword>")<CR><CR>
		noremap <leader>ca :VimScope a <C-R>=expand("<cword>")<CR><CR>
		set cscopequickfix=s+,c+,d+,i+,t+,e+,g+
		set csto=0
		set cst
		set csverb
	endif
	
	" cscope update
	noremap <leader>cb :call vimmake#Update_Tags('.tags', '')<cr>
	noremap <leader>cm :call vimmake#Update_Tags('', '.cscope')<cr>
endfunc

command! -nargs=0 MakeKeymap call s:Cmd_MakeKeymap()

function! vimmake#MakeKeymap()
	MakeKeymap
endfunc

function! vimmake#Load()
endfunc

function! vimmake#Toggle_Quickfix()
	let l:open = 0
	if exists('b:quickfix_open')
		if b:quickfix_open != 0
			let l:open = 1
		endif
	endif
	if l:open == 0
		exec "botright copen 6"
		exec "wincmd k"
		if &number == 0
			set number
		endif
		set laststatus=2
		let b:quickfix_open = 1
	else
		exec "cclose"
		let b:quickfix_open = 0
	endif
endfunc

function! vimmake#Update_FileList(outname)
	let l:names = ['*.c', '*.cpp', '*.cc', '*.cxx']
	let l:names += ['*.h', '*.hpp', '*.hh', '*.py', '*.pyw', '*.java', '*.js']
	if has('win32') || has("win64") || has("win16")
		silent! exec '!dir /b ' . join(l:names, ',') . ' > '.a:outname
	else
		let l:cmd = ''
		let l:ccc = 1
		for l:name in l:names
			if l:ccc == 1
				let l:cmd .= ' -name "'.l:name . '"'
				let l:ccc = 0
			else
				let l:cmd .= ' -o -name "'.l:name. '"'
			endif
		endfor
		silent! exec '!find . ' . l:cmd . ' > '.a:outname
	endif
	redraw!
endfunc

function! vimmake#Update_Tags(ctags, cscope)
	echo "update tags"
	if a:ctags != "" 
		if filereadable(a:ctags) | call delete(a:ctags) | endif
		let l:parameters = ' --fields=+iaS --extra=+q --c++-kinds=+px '
		exec '!ctags -R -f '.a:ctags. l:parameters . ' .'
	endif
	if has("cscope") && a:cscope != ""
		silent! exec "cs kill -1"
		if filereadable(a:cscope) | call delete(a:cscope) | endif
		exec '!cscope -b -R -f '.a:cscope
		if filereadable(a:cscope)
			exec 'cs add '.a:cscope
		endif
	endif
	redraw!
endfunc




