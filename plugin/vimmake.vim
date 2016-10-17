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

" ring bell after exit
if !exists("g:vimmake_build_bell")
	let g:vimmake_build_bell = 0
endif

" signal to stop job
if !exists('g:vimmake_build_stop')
	let g:vimmake_build_stop = 'term'
endif

" check cursor of quickfix window in last line
if !exists('g:vimmake_build_last')
	let g:vimmake_build_last = 0
endif

" build status
if !exists('g:vimmake_build_status')
	let g:vimmake_build_status = ''
endif

" auto scroll quickfix
if !exists('g:vimmake_build_scroll')
	let g:vimmake_build_scroll = 0
endif

" shell encoding
if !exists('g:vimmake_build_encoding')
	let g:vimmake_build_encoding = ''
endif

" trim empty lines ?
if !exists('g:vimmake_build_trim')
	let g:vimmake_build_trim = 0
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
if v:version >= 800 || has('patch-7.4.1829') || has('nvim')
	if has('job') && has('channel') && has('timers') && has('reltime') 
		let s:vimmake_advance = 1
		let g:vimmake_advance = 1
	elseif has('nvim')
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
	if g:vimmake_save != 0
		try
			silent exec "update"
		catch /.*/
		endtry
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
function! Vimmake_Command(command, target, mode)
	let $VIM_FILEPATH = expand("%:p")
	let $VIM_FILENAME = expand("%:t")
	let $VIM_FILEDIR = expand("%:p:h")
	let $VIM_FILENOEXT = expand("%:t:r")
	let $VIM_FILEEXT = "." . expand("%:e")
	let $VIM_CWD = getcwd()
	let $VIM_RELDIR = expand("%:h:.")
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
	if type(a:command) == 1
		let l:cmd = a:command
	else
		let l:tmp = []
		for l:item in a:command
			let l:tmp += [shellescape(l:item)]
		endfor
		let l:cmd = join(l:tmp, ' ')
	endif
	if (a:mode == 0) || ((!has("quickfix")) && a:mode == 1)
		if s:vimmake_windows != 0 && has('gui_running')
			let l:tmp = fnamemodify(tempname(), ':h') . '\vimmake.cmd'
			let l:run = ['@echo off', l:cmd, 'pause']
			if v:version >= 700
				call writefile(l:run, l:tmp)
			else
				exe 'redir! > '. fnameescape(l:tmp)
				silent echo "@echo off"
				silent echo l:cmd
				silent echo "pause"
				redir END
			endif
			let l:ccc = shellescape(l:tmp)
			silent exec '!start cmd /c '. l:ccc
		else
			exec '!' . l:cmd
		endif
	elseif (a:mode == 1)
		call s:MakeSave()
		let &l:makeprg = l:cmd
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
			if type(a:command) == 1
				python x = [vim.eval('a:command')]
			else
				python x = vim.eval('a:command')
			endif
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
			if type(a:command) == 1
				call call(g:vimmake_runner, [a:command])
			else
				call call(g:vimmake_runner, a:command)
			endif
		else
			echohl ErrorMsg
			echom "ERROR: g:vimmake_runner is empty"
			echohl NONE
		endif
	elseif (a:mode == 8)
		exec '!' . l:cmd
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
let s:build_neovim = has('nvim')? 1 : 0

" check :cbottom available
if has('patch-7.4.1997') && (!has('nvim'))
	let s:build_quick = 1
endif

" scroll quickfix down
function! s:Vimmake_Build_Scroll()
	if getbufvar('%', '&buftype') == 'quickfix'
		silent normal G
	endif
endfunc

" check last line
function! s:Vimmake_Build_Cursor()
	if &buftype == 'quickfix'
		if s:build_neovim != 0
			let w:vimmake_build_qfview = winsaveview()
		endif
		if line('.') != line('$')
			let s:build_last = 0
		endif
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

" restore view in neovim
function! s:Vimmake_Build_NeoReset()
	if &buftype == 'quickfix'
		if exists('w:vimmake_build_qfview')
			call winrestview(w:vimmake_build_qfview)
			unlet w:vimmake_build_qfview
		endif
	endif
endfunc

" neoview will reset cursor when caddexpr is invoked
function! s:Vimmake_Build_NeoRestore()
	if &buftype == 'quickfix'
		call s:Vimmake_Build_NeoReset()
	else
		let l:winnr = winnr()
		windo call s:Vimmake_Build_NeoReset()
		silent exec ''.l:winnr.'wincmd w'
	endif
endfunc

" check if quickfix window can scroll now
function! s:Vimmake_Build_CheckScroll()
	if g:vimmake_build_last == 0
		if &buftype == 'quickfix'
			if s:build_neovim != 0
				let w:vimmake_build_qfview = winsaveview()
			endif
			return (line('.') == line('$'))
		else
			return 1
		endif
	elseif g:vimmake_build_last == 1
		let s:build_last = 1
		let l:winnr = winnr()
		windo call s:Vimmake_Build_Cursor()
		silent exec ''.l:winnr.'wincmd w'
		return s:build_last
	elseif g:vimmake_build_last == 2
		return 1
	else
		if &buftype == 'quickfix'
			if s:build_neovim != 0
				let w:vimmake_build_qfview = winsaveview()
			endif
			return (line('.') == line('$'))
		else
			return (!pumvisible())
		endif
	endif
endfunc

" invoked on timer or finished
function! s:Vimmake_Build_Update(count)
	let l:iconv = (g:vimmake_build_encoding != "")? 1 : 0
	let l:count = 0
	let l:total = 0
	let l:check = s:Vimmake_Build_CheckScroll()
	if g:vimmake_build_encoding == &encoding
		let l:iconv = 0 
	endif
	while s:build_tail < s:build_head
		let l:text = s:build_output[s:build_tail]
		if l:iconv != 0
			try
				let l:text = iconv(l:text, 
					\ g:vimmake_build_encoding, &encoding)
			catch /.*/
			endtry
		endif
		if l:text != ''
			caddexpr l:text
		elseif g:vimmake_build_trim == 0
			caddexpr "\n"
		endif
		let l:total += 1
		unlet s:build_output[s:build_tail]
		let s:build_tail += 1
		let l:count += 1
		if a:count > 0 && l:count >= a:count
			break
		endif
	endwhile
	if l:check != 0
		if and(g:vimmake_build_scroll, 1) != 0 && l:total > 0
			call s:Vimmake_Build_AutoScroll()
		elseif s:build_neovim != 0
			call s:Vimmake_Build_NeoRestore()
		endif
		if and(g:vimmake_build_scroll, 8) != 0
			silent clast
		endif
	elseif s:build_neovim != 0
		call s:Vimmake_Build_NeoRestore()
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
	elseif a:what == 1
		let s:build_state = or(s:build_state, 4)
	else
		let s:build_state = 7
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
	let l:check = s:Vimmake_Build_CheckScroll()
	if s:build_code == 0
		let l:text = "[Finished in ".l:last." seconds]"
		call setqflist([{'text':l:text}], 'a')
		let g:vimmake_build_status = "success"
	else
		let l:text = 'with code '.s:build_code
		let l:text = "[Finished in ".l:last." seconds ".l:text."]"
		call setqflist([{'text':l:text}], 'a')
		let g:vimmake_build_status = "failure"
	endif
	let s:build_state = 0
	if l:check != 0
		if and(g:vimmake_build_scroll, 1) != 0
			call s:Vimmake_Build_AutoScroll()
		elseif s:build_neovim != 0
			call s:Vimmake_Build_NeoRestore()
		endif
		if and(g:vimmake_build_scroll, 4) != 0
			silent clast
		endif
	else
		call s:Vimmake_Build_NeoRestore()
	endif
	if g:vimmake_build_bell != 0
		exec 'norm! \<esc>'
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

" invoked on neovim when stderr/stdout/exit
function! g:Vimmake_Build_NeoVim(job_id, data, event)
	if a:event == 'stdout' || a:event == 'stderr'
		let l:index = 0
		let l:size = len(a:data)
		while l:index < l:size
			let s:build_output[s:build_head] = a:data[l:index]
			let s:build_head += 1
			let l:index += 1
		endwhile
		call s:Vimmake_Build_Update(-1)
	elseif a:event == 'exit'
		call s:Vimmake_Build_OnFinish(2)
	endif
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
		if s:build_neovim == 0
			if job_status(s:build_job) == 'run'
				let l:running = 1
			endif
		else
			if s:build_job > 0
				let l:running = 1
			endif
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
	endif
	if l:empty != 0
		echo "empty cmd"
		return -3
	endif
	if !filereadable(&shell)
		let l:text = "invalid config in &shell and &shellcmdflag"
		call s:ErrorMsg(l:text . ", &shell must be an executable.")
		return -4
	endif
	let l:args = [&shell, &shellcmdflag]
	let l:name = []
	if type(a:cmd) == 1
		let l:name = a:cmd
		if s:vimmake_windows == 0
			let l:args += [a:cmd]
		else
			let l:tmp = fnamemodify(tempname(), ':h') . '\vimmake.cmd'
			let l:run = ['@echo off', a:cmd]
			call writefile(l:run, l:tmp)
			let l:args += [shellescape(l:tmp)]
		endif
	elseif type(a:cmd) == 3
		if s:vimmake_windows == 0
			let l:temp = []
			for l:item in a:cmd
				if index(['|', '`'], l:item) < 0
					let l:temp += [fnameescape(l:item)]
				else
					let l:temp += ['|']
				endif
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
	if s:build_neovim == 0
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
		let l:success = (job_status(s:build_job) != 'fail')? 1 : 0
	else
		let l:callbacks = {'shell': 'VimMake'}
		let l:callbacks['on_stdout'] = function('g:Vimmake_Build_NeoVim')
		let l:callbacks['on_stderr'] = function('g:Vimmake_Build_NeoVim')
		let l:callbacks['on_exit'] = function('g:Vimmake_Build_NeoVim')
		let s:build_job = jobstart(l:args, l:callbacks)
		let l:success = (s:build_job > 0)? 1 : 0
	endif
	if l:success != 0
		let s:build_output = {}
		let s:build_head = 0
		let s:build_tail = 0
		let l:arguments = "[".l:name."]"
		let l:title = ':VimMake '.l:name
		if s:build_neovim == 0
			if has('patch-7.4.2210')
				call setqflist([], ' ', {'title':l:title})
			else
				call setqflist([], ' ')
			endif
		else
			call setqflist([], ' ', l:title)
		endif
		call setqflist([{'text':l:arguments}], 'a')
		let s:build_start = float2nr(reltimefloat(reltime()))
		if g:vimmake_build_timer > 0 && s:build_neovim == 0
			let l:options = {'repeat':-1}
			let l:name = 'g:Vimmake_Build_OnTimer'
			let s:build_timer = timer_start(100, l:name, l:options)
		endif
		let s:build_state = 1
		let g:vimmake_build_status = "running"
		redrawstatus!
	else
		unlet s:build_job
		call s:ErrorMsg("Background job start failed '".a:cmd."'")
		return -5
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
		if s:build_neovim == 0
			if job_status(s:build_job) == 'run'
				call job_stop(s:build_job, l:how)
			else
				return -2
			endif
		else
			if s:build_job > 0
				call jobstop(s:build_job)
			endif
		endif
	else
		return -3
	endif
	return 0
endfunc

" get job status
function! g:Vimmake_Build_Status()
	if exists('s:build_job')
		if s:build_neovim == 0
			return job_status(s:build_job)
		else
			return 'run'
		endif
	else
		return 'none'
	endif
endfunc



"----------------------------------------------------------------------
" Replace string
"----------------------------------------------------------------------
function! s:StringReplace(text, old, new)
	let l:data = split(a:text, a:old, 1)
	return join(l:data, a:new)
endfunc


"----------------------------------------------------------------------
" Trim leading and tailing spaces
"----------------------------------------------------------------------
function! s:StringStrip(text)
	return substitute(a:text, '^\s*\(.\{-}\)\s*$', '\1', '')
endfunc


"----------------------------------------------------------------------
" extract options from command
"----------------------------------------------------------------------
function! s:ExtractOpt(command) 
	let cmd = a:command
	let opts = {}
	while cmd =~# '^-\%(\w\+\)\%([= ]\|$\)'
		let opt = matchstr(cmd, '^-\zs\w\+')
		if cmd =~ '^-\w\+='
			let val = matchstr(cmd, '^-\w\+=\zs\%(\\.\|\S\)*')
		else
			let val = (opt == 'cwd')? '' : 1
		endif
		if opt == 'cwd'
			let opts.cwd = fnamemodify(expand(val), ':p:s?[^:]\zs[\\/]$??')
		elseif index(['mode', 'program', 'save'], opt) >= 0
			let opts[opt] = substitute(val, '\\\(\s\)', '\1', 'g')
		endif
		let cmd = substitute(cmd, '^-\w\+\%(=\%(\\.\|\S\)*\)\=\s*', '', '')
	endwhile
	let cmd = substitute(cmd, '^\s*\(.\{-}\)\s*$', '\1', '')
	let cmd = substitute(cmd, '^@\s*', '', '')
	let opts.cwd = get(opts, 'cwd', '')
	let opts.mode = get(opts, 'mode', '')
	let opts.save = get(opts, 'save', '')
	let opts.program = get(opts, 'program', '')
	if 0
		echom 'cwd:'. opts.cwd
		echom 'mode:'. opts.mode
		echom 'save:'. opts.save
		echom 'program:'. opts.program
		echom 'command:'. cmd
	endif
	return [cmd, opts]
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
	if a:bang != '!'
		silent call s:CheckSave()
	endif
	if type(l:value) == 0 
		let l:mode = string(l:value) 
	else
		let l:mode = l:value
	endif
	if index(['', '0', 'normal', 'default'], l:mode) >= 0
		call Vimmake_Command(l:fullname, l:target, 0)
	elseif index(['1', 'quickfix', 'make', 'makeprg'], l:mode) >= 0
		call Vimmake_Command(l:fullname, l:target, 1)
	elseif index(['2', 'system', 'silent'], l:mode) >= 0
		call Vimmake_Command(l:fullname, l:target, 2)
	elseif index(['3', 'background', 'bg'], l:mode) >= 0
		call Vimmake_Command(l:fullname, l:target, 3)
	elseif index(['4', 'minimal', 'm', 'min'], l:mode) >= 0
		call Vimmake_Command(l:fullname, l:target, 4)
	elseif index(['5', 'python', 'p', 'py'], l:mode) >= 0
		call Vimmake_Command(l:fullname, l:target, 5)
	elseif index(['6', 'async', 'job', 'channel'], l:mode) >= 0
		call Vimmake_Command(l:fullname, l:target, 6)
	elseif index(['7', 'runner', 'extern'], l:mode) >= 0
		call Vimmake_Command(l:fullname, l:target, 7)
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
" VimMake
"----------------------------------------------------------------------
if !exists('g:vimmake_build_mode')
	let g:vimmake_build_mode = 0
endif

function! s:Cmd_VimMake(bang, mods, args)
	let l:macros = {}
	let l:macros['VIM_FILEPATH'] = expand("%:p")
	let l:macros['VIM_FILENAME'] = expand("%:t")
	let l:macros['VIM_FILEDIR'] = expand("%:p:h")
	let l:macros['VIM_FILENOEXT'] = expand("%:t:r")
	let l:macros['VIM_FILEEXT'] = "." . expand("%:e")
	let l:macros['VIM_CWD'] = getcwd()
	let l:macros['VIM_RELDIR'] = expand("%:h:.")
	let l:macros['VIM_RENAME'] = expand("%:p:.")
	let l:macros['VIM_CWORD'] = expand("<cword>")
	let l:macros['VIM_CFILE'] = expand("<cfile>")
	let l:macros['VIM_VERSION'] = ''.v:version
	let l:macros['VIM_SVRNAME'] = v:servername
	let l:macros['VIM_COLUMNS'] = ''.&columns
	let l:macros['VIM_LINES'] = ''.&lines
	let l:macros['VIM_GUI'] = has('gui_running')? 1 : 0
	let l:macros['<cwd>'] = getcwd()
	let l:command = s:StringStrip(a:args)
	let cd = haslocaldir()? 'lcd ' : 'cd '

	" extract options
	let [l:command, l:opts] = s:ExtractOpt(l:command)

	" replace macros and setup environment variables
	for [l:key, l:val] in items(l:macros)
		let l:replace = (l:key[0] != '<')? '$('.l:key.')' : l:key
		if l:key[0] != '<'
			exec 'let $'.l:key.' = l:val'
		endif
		let l:command = s:StringReplace(l:command, l:replace, l:val)
		let l:opts.cwd = s:StringReplace(l:opts.cwd, l:replace, l:val)
	endfor

	" check if need to save
	if get(l:opts, 'save', '')
		try
			silent update
		catch /.*/
		endtry
	endif

	let l:save_scroll = g:vimmake_build_scroll

	" check mode
	let l:mode = g:vimmake_build_mode

	if l:opts.mode != ''
		let l:mode = l:opts.mode
	endif

	" process makeprg/grepprg in -program=?
	let l:program = ""

	if l:opts.program == 'make'
		let l:program = &makeprg
	elseif l:opts.program == 'grep'
		let l:program = &grepprg
	endif

	if l:program != ''
		if l:program =~# '\$\*'
			let l:command = s:StringReplace(l:program, '\$\*', l:command)
		elseif l:command != ''
			let l:command = l:program . ' ' . l:command
		else
			let l:command = l:program
		endif
		let l:command = s:StringStrip(l:command)
	endif

	if l:command =~ '^\s*$'
		echohl ErrorMsg
		echom "E471: Command required"
		echohl NONE
		return
	endif

	if l:opts.cwd != ''
		let l:opts.savecwd = getcwd()
		try
			exec cd . fnameescape(l:opts.cwd)
		catch /.*/
			echohl ErrorMsg
			echom "E344: Can't find directory \"".l:opts.cwd."\" in -cwd"
			echohl NONE
			return
		endtry
	endif

	if l:mode == 0 && s:vimmake_advance != 0
		call Vimmake_Command(l:command, '', 6)
	elseif l:mode <= 1 && has('quickfix')
		call Vimmake_Command(l:command, '', 1)
	elseif l:mode <= 2
		call Vimmake_Command(l:command, '', 0)
	elseif l:mode <= 3
		call Vimmake_Command(l:command, '', 3)
	elseif l:mode <= 4
		call Vimmake_Command(l:command, '', 8)
	endif
endfunc


command! -bang -nargs=+ -complete=file VimMake 
		\ call s:Cmd_VimMake("<bang>", '', <q-args>)


"----------------------------------------------------------------------
"- make via gcc
"----------------------------------------------------------------------
function! s:Make_Gcc(filename, mode)
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
	if a:mode == 0 && s:vimmake_advance != 0
		let l:output = fnamemodify(a:filename, ':r')
		let l:cmd = [l:cc, '-Wall', a:filename, '-o', l:output]
		let l:cmd += g:vimmake_cflags
		if index(['cpp', 'cc', 'cxx', 'mm'], l:extname) >= 0
			let l:cmd += ['-lstdc++']
		endif
		call Vimmake_Build_Start(l:cmd)
	elseif a:mode <= 1 && has('quickfix')
		call s:MakeSave()
		let l:cmd = l:cc . ' -Wall '. l:source . ' -o ' . l:output
		let &l:makeprg = l:cmd . ' ' . l:flags
		exec 'make!'
		call s:MakeRestore()
	else
		let l:cmd = l:cc . ' -Wall '. l:source . ' -o ' . l:output
		if s:vimmake_windows == 0
			exec '!'.l:cmd . ' ' . l:flags
		else
			exec '!start cmd.exe /C '.l:cmd. ' '.l:flags.' & pause'
		endif
	endif
endfunc


"----------------------------------------------------------------------
"- build via gcc/make/emake
"----------------------------------------------------------------------
function! s:Cmd_VimBuild(bang, ...)
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
	let l:what = a:1
	let l:conf = ""
	if a:0 >= 2
		let l:conf = a:2
	endif
	if index(['0', 'gcc', 'cc'], l:what) >= 0
		call s:Make_Gcc(expand("%"), g:vimmake_build_mode)
	elseif index(['1', 'make'], l:what) >= 0
		if l:conf == ''
			exec 'VimMake make'
		else
			exec 'VimMake make '.shellescape(l:conf)
		endif
	elseif index(['2', 'emake'], l:what) >= 0
		if l:conf == ''
			exec 'VimMake emake '. shellescape('%')
		else
			exec 'VimMake emake --ini='.shellescape(l:conf).' "%"'
		endif
	endif
endfunc


command! -bang -nargs=* VimBuild call s:Cmd_VimBuild('<bang>', <f-args>)



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
		let l:text = 'assigned "'.a:name.'"'
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
	noremap <silent><F7> :VimBuild emake<cr>
	noremap <silent><F8> :VimExecute emake<cr>
	noremap <silent><F9> :VimBuild gcc<cr>
	noremap <silent><F10> :call vimmake#Toggle_Quickfix(6)<cr>
	inoremap <silent><F5> <ESC>:VimExecute run<cr>
	inoremap <silent><F6> <ESC>:VimExecute filename<cr>
	inoremap <silent><F7> <ESC>:VimBuild emake<cr>
	inoremap <silent><F8> <ESC>:VimExecute emake<cr>
	inoremap <silent><F9> <ESC>:VimBuild gcc<cr>
	inoremap <silent><F10> <ESC>:call vimmake#Toggle_Quickfix(6)<cr>

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
		noremap <leader>cd :VimScope d <C-R>=expand("<cword>")<CR><CR>
		noremap <leader>ca :VimScope a <C-R>=expand("<cword>")<CR><CR>
		noremap <leader>cf :VimScope f <C-R>=expand("<cfile>")<CR><CR>
		noremap <leader>ci :VimScope i <C-R>=expand("<cfile>")<CR><CR>
		if has('patch-7.4.2038')
			set cscopequickfix=s+,c+,d+,i+,t+,e+,g+,f+,a+
		else
			set cscopequickfix=s+,c+,d+,i+,t+,e+,g+,f+
		endif
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

function! vimmake#Toggle_Quickfix(size)
	function! s:WindowCheck(mode)
		if getbufvar('%', '&buftype') == 'quickfix'
			let s:quickfix_open = 1
			return
		endif
		if a:mode == 0
			let w:quickfix_save = winsaveview()
		else
			call winrestview(w:quickfix_save)
		endif
	endfunc
	let s:quickfix_open = 0
	let l:winnr = winnr()			
	windo call s:WindowCheck(0)
	if s:quickfix_open == 0
		exec 'botright copen '.a:size
		wincmd k
	else
		cclose
	endif
	windo call s:WindowCheck(1)
	try
		silent exec ''.l:winnr.'wincmd w'
	catch /.*/
	endtry
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




