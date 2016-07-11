# Vimmake

Customize shell tools for vim. Similar to 'Run Commands' in NotePad++, 'User Tool' in EditPlus/UltraEdit, 'External Tool' in GEdit and 'Shell Commands' in TextMate. 

## Preface

This plugin is inspired by GEdit's `External Tool` which enables you to compile and run your project in a efficient way. Each tool is a single shell script defined by user which can be used to execute Makefile or compile/run a single file with customizable compile flags and run options. 

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

Copy vimmake.vim to your ~/.vim/plugin or using Vundle to install it from `skywind3000/vimmake` .

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

At last, hotkeys can be setup in `.vimrc` to speed up your compile-edit-compile cycle:

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

## Playing Sound

We have `afplay` to play a wav file in mac os x to notify when async job finished:

```VimL
let g:vimmake_build_post = "silent call system('afplay ~/.vim/notify.wav &')"
```

It is useful while you are editing, you have your eyes looking at the source code without worry about the progress of background building jobs. You don't need repeatly move your eyes from souce code area to quickfix window and from quickfix window back to source code area.

Using a voice notification may help you focus on the source code. In windows you need `:!start` to invoke an external command line tool asynchronous, see `:help !start`:

```VimL
let g:vimmake_build_post = 'silent !start playwav.exe "C:\Windows\Media\Windows Error.wav" 200'
```

`playwav.exe` is a command line utility to play .wav files in windows. `playwav.exe` can be download [here](https://github.com/skywind3000/support/blob/master/tools/playwav.exe). 

Choosing a sweet-sounding .wav file is important which will please you in your subconscious. It will encourage you to continue debug-compile-debug-compile even when you are exhausted from finding bugs.

You can be more productive when you are using voice notifications. The more you use, the more you get happy, nothing can attract or stop you from your crazy edit-debug-edit-debug cycle.

## Misc

Vimmake has been tested in console and gui version. You can use 'open' in mac os or '/usr/bin/gnome-terminal' in ubuntu to open a new window and execute your command from tool scripts. 

As executing program in a new terminal window correctly is a little tricky thing, I create a script to let you open a new terminal window to execute your program in both Windows, Linux (ubuntu), Cygwin and Mac OS X, you can try it from: https://github.com/skywind3000/terminal.

## Reference

http://www.vim.org/scripts/script.php?script_id=5418, 
Please vote it if you like it.  