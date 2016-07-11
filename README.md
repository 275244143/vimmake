# Vimmake

Customize shell tools for vim. Similar to 'Run Commands' in NotePad++, 'User Tool' in EditPlus/UltraEdit, 'External Tool' in GEdit and 'Shell Commands' in TextMate. 

## Preface

This plugin is inspired by GEdit's `External Tool` which enables you to compile and run your project in a efficient way. Each tool is represented by a single shell script created by user which can be used to execute Makefile or compile/run a single file with customizable compile flags and run options. 

Vim has numerous community plugins for building or running programs, and I have tried some. Most of them are really great in certain extent but still cannot fully satisfy my need. Therefore I decided to reference their packages and make my own.

## Feature

- Customize user tool to invoke compiler or other tools with current file or directory.
- Tools can be created as a single shell script in unix like system or a batch file in windows (.cmd/.bat).
- Tools can be launched by `:VimTool {name}` with given system environment variables
- Launch mode can be configured as `sync`, `async` or `silent` (run in background and discard output).
- Output can be captured and display in the quickfix window in realtime.
- Ex-command `:VimTool {name}` and `:VimStop` can be binded to your favorite keymaps.
- Error output can be matched in quickfix window.
- Simple and lightweight.


## Installation

Copy vimmake.vim to your ~/.vim/plugin or use Vundle to install it from `skywind3000/vimmake` .

## Tutorials

Create a customize building tool by editing the shell script named `"~/.vim/vimmake.gcc"`:

```bash
#! /bin/sh
gcc "$VIM_FILEPATH" -o "$VIM_FILEDIR/$VIM_FILENOEXT"
```

After changing file mode to 0755, you can launch it inside vim with the command `:VimTool`:

```
:VimTool gcc
```

It can be used to compile the current source file. Now we will edit `"~/.vim/vimmake.run"` to run our source:

```bash
#! /bin/sh
"$VIM_FILEDIR/$VIM_FILENOEXT"
```

Remeber changing file mode to 0755, and you can launch it by `:VimTool run`. Now we have two tools named `gcc` and `run`, which can be executed directly inside vim.

We need capture the output of `gcc` to the quickfix window, just setup g:vimmake_mode in your `.vimrc`:

```VimL
let g:vimmake_mode = { 'gcc':'quickfix', 'run':'normal' }
```

Or use async-building mode (require vim 7.4.1829 or above), which will launch `gcc` in background and redirect the output into quickfix window in realtime:

```VimL
let g:vimmake_mode = { 'gcc':'async', 'run':'normal' }
```

After that, `:VimTool gcc` can run in async mode now, the experience is just like building project in IDEs:

![demo](https://raw.githubusercontent.com/skywind3000/vimmake/master/images/screen1.gif)

Building while editing in the same time is difficult in the old days, but now vimmake enables you to take the advange of async jobs in a very simply way.  

At last, hotkeys can be setup in `.vimrc` to speed up your edit-compile-run workflow:

```VimL
noremap <F7> :VimTool gcc<cr>
noremap <F5> :VimTool run<cr>
inoremap <F7> <ESC>:VimTool gcc<cr>
inoremap <F5> <ESC>:VimTool run<cr>
```

Now you can have your F7/F5 to compile/run your source file.


## Command

### VimTool - launch the user tool 

This will launch `"~/.vim/vimmake.{name}"` in unix and `"~/.vim/vimmake.{name}.cmd"` in window:

```VimL
:VimTool {name}
```

A `{target}` can also be passed after `{name}`, which will be used to initialize `$VIM_TARGET`:

```VimL
:VimTool {name} {target}
```

Script can use this value as build target and pass as a parameter of gnumake.

The command `:VimTool` will setup the environment variables for launching:

| Environment Variable | Description |
|----------------------|-------------|
| $VIM_FILEPATH | File name of current buffer with full path |
| $VIM_FILENAME | File name of current buffer without path |
| $VIM_FILEDIR | Full path of current buffer without the file name |
| $VIM_FILEEXT | File extension of current buffer |
| $VIM_FILENOEXT | File name of current buffer without path and extension |
| $VIM_CWD | Current directory |
| $VIM_RELDIR | File path relativize to current directory |
| $VIM_RELNAME | File name relativize to current directory  |
| $VIM_CWORD | Current word under cursor in the buffer |
| $VIM_GUI | Is it running in gui ? |
| $VIM_VERSION | Value of v:version |
| $VIM_MODE | Execute via 0:bang(!), 1:makeprg, 2:system(), ... |
| $VIM_SCRIPT | Home path of tool scripts |
| $VIM_TARGET | Target given after name as ":VimTool {name} {target}" |
| $VIM_COLUMNS | How many columns in vim's screen |
| $VIM_LINES | How many lines in vim's screen |


You can setup as many tools as you wish to build your project makefile, or compile a single source file directly, or compile your latex, or run grep in current directory, passing current word under cursor to external man help / dictionary / other external scripts, or just call svn diff with current file and redirect the output to the bottom panel.

### VimStop - stop the user tool in background

This command will stop the current async building job.


## Configuration

Edit your `.vimrc` to configurate vimmake in details:

### g:vimmake_mode (dictionary) - launch mode

Setup launch mode to indicate how to execute the tools:

```VimL
let g:vimmake_mode = {}
let g:vimmake_mode['gcc'] = 'async'
let g:vimmake_mode['run'] = 'normal'
```

Launch mode can be one of these:

| Launch mode | Detail |
|-------------|--------|
| normal | Default, launch the tool and return to vim after exit |
| quickfix | Launch and redirect output to quickfix window |
| bg | Launch in background and discard any output |
| async | Run in async mode and redirect output to quickfix in realtime |

Default value of `g:vimmake_mode` is `{}` which means all the tool will be launched in `normal` mode. `Normal` in windows version of gvim will launch the tool in a new cmd window by using `!start`.

To open a new terminal window and execute your tool in ubuntu, you may invoke gnome-terminal in the tool script and launch the script in `bg` mode. In Mac OS X, `open` can be used to open a terminal window and run the given script.

Vim 7.4.1829 is required for using `async` mode.

Output can be viewed in quickfix window, to open the quickfix window, you can use `:copen 8` or `:botright copen 8` to open quickfix window in different position. See `:help quickfix` for detail.


### g:vimmake_path (string) - tool path

This option allows you to change the home directory of tools rather than `"~/.vim/"`.

```VimL
let g:vimmake_path = '/home/myname/github/config/tools'
```

Now `:VimTool {name}` will launch `vimmake.{name}` from `"/home/myname/github/config/tools"`. so you can put your tool scripts into some git/svn repositories and get it sync every where.

### g:vimmake_save (int) - save before launch ?

It can be set to 1 if you want to save current file before execute a tool.

### g:vimmake_build_scroll (int) - auto-scroll quickfix ?

When it is set to 1 for async building, quickfix window will scroll to last line automaticly if there is a new output line added to quickfix.

### g:vimmake_build_post (string) - post async commands

When async building job is finished, script in `g:vimmake_build_post` will be executed. It can be used to invoke a external program:

```VimL
let g:vimmake_build_post = "silent call system('afplay ~/.vim/notify.wav &')"
```

Now `~/.vim/notify.wav` will be played to notify you the async job is finished now. `Afplay` is a command line utility to play .wav files in mac os x.


## Examples

### Run current file

Create `"~/.vim/vimmake.run"` to execute current file/buffer with command `:VimTool run`:

```bash
#! /bin/sh

cd "$VIM_FILEDIR"

case "$VIM_FILEEXT" in 
	\.c|\.cpp|\.cc|\.cxx)
		"$VIM_FILEDIR/$VIM_FILENOEXT"
		;;
	\.py|\.pyw)
		python "$VIM_FILENAME"
		;;
	\.pl)
		perl "$VIM_FILENAME"
		;;
	\.lua)
		lua "$VIM_FILENAME"
		;;
	\.js)
		node "$VIM_FILENAME"
		;;
	\.php)
		php "$VIM_FILENAME"
		;;
	*)
		echo "unexpected file type: $VIM_FILEEXT"
		;;
esac

```

We have a simple `run` script in tutorials and this is a more clever version. It detects file type with `$VIM_FILEEXT` and chooses the right way to run. And you can extend this script easily for new file types.

Shell scripts can be written not only in bash, but also in whatever language you like (eg. `#! /usr/bin/python` for python). Only need to ensure the file mode is 0755 (has execute permission).

### Compile makefile

Create `"~/.vim/vimmake.make"` to build your makefile with `:VimTool make` or `:VimTool make {target}`:

```bash
#! /bin/sh
make $VIM_TARGET
```

Ensure that `g:vimmake_mode["make"]` has been set to "quickfix" or "async" (vim 7.4.1829 or above) in your `.vimrc`, so that the output can be captured in the quickfix window.

### Lookup keywords in man

Create `"~/.vim/vimmake.man"` to check current word under cursor from `man` and output result to the quickfix window:

```bash
#! /bin/sh

WIDTH=`expr $VIM_COLUMNS - 10`
man -S 3:2:1 -P cat "$VIM_CWORD" | fold -w $WIDTH
```

Ensure that `g:vimmake_mode["man"]` has been set to "quickfix" or "async". `$VIM_CWORD` contains the word under cursor and `$VIM_COLUMNS` indicate vim's screen width.

With `$$VIM_CWORD` you can do so many things like: lookup words from a manual for help, or a dictionary for translating, or just call an external grep-like program and get the output in quickfix window.


### Compile .go source

Create `"~/.vim/vimmake.go"` to compile your file with `:VimTool go`:

```bash
#! /bin/sh
go build "$VIM_FILEPATH"
```

Ensure that `g:vimmake_mode["go"]` has been set to "quickfix" or "async", so that output can be captured in the quickfix window.

### Setup keymap

Edit your `.vimrc` to configurate keymap:

```VimL
noremap <F7> :VimTool gcc<cr>
noremap <F5> :VimTool run<cr>
inoremap <F7> <ESC>:VimTool gcc<cr>
inoremap <F5> <ESC>:VimTool run<cr>
```

Now you can have your F7/F5 to compile/run your source file.

### Hotkey to toggle quickfix window
 
Edit your `.vimrc` to configurate keymaps:

```VimL
noremap <F10> :silent call vimmake#Toggle_Quickfix()<cr>
inoremap <F10> <ESC>:silent call vimmake#Toggle_Quickfix()<cr>
```

Quickfix window can be toggled by pressing F10, you can use quickfix window to view output and navigate errors (see `:help quickfix`).

### Run current file in windows

Create a batch file named `"C:/Users/yourname/.vim/vimmake.run.cmd"`:

```batch
@ECHO OFF
if "%VIM_FILENAME%" == "" GOTO ERROR_NO_FILE
CD /D "%VIM_FILEDIR%"

if "%VIM_FILEEXT%" == ".c" GOTO RUN_MAIN
if "%VIM_FILEEXT%" == ".cpp" GOTO RUN_MAIN
if "%VIM_FILEEXT%" == ".cc" GOTO RUN_MAIN
if "%VIM_FILEEXT%" == ".cxx" GOTO RUN_MAIN
if "%VIM_FILEEXT%" == ".py" GOTO RUN_PY
if "%VIM_FILEEXT%" == ".pyw" GOTO RUN_PY
if "%VIM_FILEEXT%" == ".bat" GOTO RUN_CMD
if "%VIM_FILEEXT%" == ".cmd" GOTO RUN_CMD
if "%VIM_FILEEXT%" == ".js" GOTO RUN_NODE

echo unsupported file type %VIM_FILEEXT%
GOTO END

:RUN_MAIN
"%VIM_FILENOEXT%"
GOTO END

:RUN_PY
python "%VIM_FILENAME%"
GOTO END

:RUN_CMD
cmd /C "%VIM_FILENAME%"
GOTO END

:RUN_NODE
node.exe "%VIM_FILENAME%"
GOTO END

:ERROR_NO_FILE
echo missing filename
GOTO END

:END

```

The location of batch files can also be changed if you don't like to access `C:/Users/yourname/.vim`. Edit your `_vimrc` in windows and add this line:

```VimL
let g:vimmake_path = 'd:/github/vim/tools/win32'
```

Now, you can save your batch files in your github repository.

### Invoke mingw in windows

Create a batch file named `"C:/Users/yourname/.vim/vimmake.gcc.cmd"`:

```batch
@ECHO OFF
if "%VIM_FILENAME%" == "" GOTO ERROR_NO_FILE

d:\dev\mingw32\bin\gcc -Wall -O3 -std=c++11 "%VIM_FILEPATH%" -o "%VIM_FILEDIR%/%VIM_FILENOEXT%" -lwinmm -lstdc++ -lgdi32 -lws2_32 -msse3 -static
GOTO END

:ERROR_NO_FILE
echo missing file name

:END
```

Ensure that `g:vimmake_mode["gcc"]` has been set to "quickfix" or "async", so that output can be captured in the quickfix window.

Using the latest gvim in windows for async-jobs is recommended, you can download from [official gvim daily build](https://github.com/vim/vim-win32-installer/releases/).

### View building progress in the status line

Async building jobs have three states: running, success and failure. You can edit your `.vimrc` to view these states in the quickfix windows' statusline:

```VimL
augroup QuickfixStatus
	au! BufWinEnter quickfix setlocal 
		\ statusline=%t\ [%{g:vimmake_build_status}]\ %{exists('w:quickfix_title')?\ '\ '.w:quickfix_title\ :\ ''}\ %=%-15(%l,%c%V%)\ %P
augroup END
```

Global variable `g:vimmake_build_status` indicates the these three states:

- running: set when a async building job is start
- success: set when the tool script exit normally which exit code is 0
- failure: set when the tool script exit abnormally which exit code is not 0

Then building progress can be watched right on quickfix windows' statusline in realtime.

## Playing Sound

We have `afplay` to play a wav file in mac os x to notify when async job finished:

```VimL
let g:vimmake_build_post = "silent call system('afplay ~/.vim/notify.wav &')"
```

It is useful while you are editing, you have your eyes looking at the source code without worry about the progress of background building jobs. You don't need repeatly move your eyes from souce code area to quickfix window and from quickfix window back to source code area.

Using a voice notification may help you focus on the source code. In windows you need `:!start` to invoke an external command line tool asynchronous, see `:help !start`:

```VimL
let g:vimmake_build_post = 'silent !start playwav.exe "C:/Windows/Media/Windows Error.wav" 200'
```

`playwav.exe` is a command line utility to play .wav files in windows which can be downloaded  from [here](https://github.com/skywind3000/support/blob/master/tools/playwav.exe). 

Choosing a sweet-sounding .wav file is important which will please you in your subconscious. It will encourage you to continue debug-compile-debug-compile even when you are exhausted from finding bugs.

You can be more productive when you are using voice notifications. The more you use, the more you get happy, nothing can attract or stop you from your crazy edit-debug-edit-debug cycle.


## Run in New Terminal Window

When you are editing a long-time-running program (eg. a HttpServer demo), a seperate terminal is needed if you are trying to run it after building. It's a good idea If we can open a new terminal window and run our program directly from vim.

When you are using vimmake under gvim in windows, it will always open a new console if launch mode is `normal`, it uses the command `:!start` in windows gvim:

![demo](https://raw.githubusercontent.com/skywind3000/vimmake/master/images/screen2.gif)

But if you are using gvim in ubuntu, you need write some extra code in your tool script, let edit a new file named `"~/.vim/vimmake.1"`:

```python
#! /usr/bin/python
import sys, os

VIM_FILEDIR=os.environ.get('VIM_FILEDIR', '')
VIM_FILENAME=os.environ.get('VIM_FILENOEXT', '')

cmd = "cd \"%s\"; %s/%s; read -n1 -rsp press\ any\ key\ to\ continue\ ..."
cmd = cmd%(VIM_FILEDIR, VIM_FILEDIR, VIM_FILENAME)
cmd = cmd.replace('\\', '\\\\').replace('"', "\\\"").replace("'", "\\\'")
cmd = 'bash -c \"%s\"'%cmd

cmdline = 'gnome-terminal --command=\'%s\''%cmd
os.system(cmdline)
```

By using python to implement 'run in new window', we will call `gnome-terminal` with correct parameters. After changing file mode to 0755 we need set launch mode of `1` to `bg` in our `.vimrc`:

```VimL
let g:vimmake_mode['1']='bg'
```

Launch mode `bg` means the python script above will be launched in the background and any output will be discard, so you will see nothing from vim's screen when you are using 'bg' mode. All we need is opening `gnome-terminal` and run our program:

![demo](https://raw.githubusercontent.com/skywind3000/vimmake/master/images/screen3.jpg)

In this way, you can launch a long-time-running program in a new open terminal while you are editing. The experience is just like debugging a console application in visual studio.

You can use 'open' in mac os or '/usr/bin/gnome-terminal' in ubuntu to open a new window and execute the commands in your tool scripts.

As executing program in a new terminal window correctly is a little tricky thing, I create a script to let you open a new terminal window and run your command in both Windows, Linux (ubuntu), Cygwin and Mac OS X, you can try it from: https://github.com/skywind3000/terminal.

## Misc

Vimmake has been well tested under ubuntu, mac os x, windows and cygwin.

Please vote it if you like it:
http://www.vim.org/scripts/script.php?script_id=5418, 



