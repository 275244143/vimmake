## Introduction

Customize shell tools for vim. Similar to 'Run Commands' in NotePad++, 'User Tool' in EditPlus/UltraEdit, 'External Tool' in GEdit and 'Shell Commands' in TextMate. 

## Preface

This plugin is inspired by GEdit's `External Tool` which allows you to compile and run your project in a efficient way. Each tool is a single shell script defined by user which can be used to execute Makefile or compile/run a single file with customizable compile flags and run options. 

Vim has numerous community plugins and I have tried some. Most of them are really great in certain extent but still cannot fully satisfy my need. Therefore I decided to reference their packages and make my own.

## Feature

- Customize user tool to invoke compiler or other tools with current file/directory.
- Each tool can be created as a single shell script in unix like system or batch file in windows (.cmd/.bat).
- Tools can be executed with given environment. 
- Output can be captured and display in the quickfix window. 
- Launch mode can be configured as `sync`, `async` or `silent` (async with no output).
- Error output can be matched in quickfix window.
- Simple and lightweight.


## Installation

Copy vimmake.vim to your ~/.vim/plugin or using Vundle to install it from `skywind3000/vimmake` .

## Setup

Create a single shell script `~/.vim/vimmake.gcc` in `~/.vim`:

```shell
#! /bin/sh
gcc "$VIM_FILEPATH" -o "$VIM_FILEDIR/$VIM_FILENOEXT"
```

After changing file mode to 0755, you can launch it inside vim with the command `VimTool`:

```
:VimTool gcc
```

Command `VimTool {name}` will launch the script `"vimmake.{name}"` in the directory of `"~/.vim"` with the predefined environment variables:

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
| $VIM_GUI | Is running under gui ? |
| $VIM_VERSION | Value of v:version |
| $VIM_MODE | Execute via 0:!, 1:makeprg, 2:system() |
| $VIM_SCRIPT | Home path of tool scripts |
| $VIM_TARGET | Target given after name as ":VimTool {name} {target}" |

You can setup as many tools as you wish to build your project makefile, or compile/run a single source file directly, or compile your latex, or run grep in current directory, passing current word under cursor to external man help / dictionary / other external scripts, or just call svn diff with current file and redirect the output to the bottom panel.

## Command

**VimTool** - launch the user tool 

```VimL
:VimTool {name}
```

This will launch `"~/.vim/vimmake.{name}"` in unix and `"~/.vim/vimmake.{name}.cmd"` in window.

```VimL
:VimTool {name} {target}
```

Launch `"~/.vim/vimmake.{name}"` and pass `{target}` in the system environment variable as `$VIM_TARGET`. Script can use this value as build target and pass as a parameter of gnumake.

**VimStop** - stop the user tool in background

This command will stop the current async building job.


## Configuration

Edit your `.vimrc` to configurate vimmake in details:

**g:vimmake_mode (dictionary)** - launch mode

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


**g:vimmake_path (string)** - tool path

This option allows you to change the home directory of tools rather than `"~/.vim/"`.

```VimL
let g:vimmake_path = '/home/myname/github/config/tools'
```

Now `:VimTool {name}` will launch `vimmake.{name}` from `"/home/myname/github/config/tools"`.

**g:vimmake_save (int)** - save before launch ?

It can be set to 1 if you want to save current file before execute a tool.

**g:vimmake_build_scroll (int)** - auto-scroll quickfix ?

When it is set to 1 for async building, quickfix window will scroll to last line automaticly if there is a new output line added to quickfix.

**g:vimmake_build_post (string)** - post vim commands

When async building job is finished, script in `g:vimmake_build_post` will be executed. It can be used to invoke a external program:

```VimL
let g:vimmake_build_post = "silent !afplay ~/.vim/notify.wav"
```

Now `~/.vim/notify.wav` will be played to notify you the async job is finished now. 


## Examples

TODO

## Misc

Vimmake has been tested in console and gui version. You can use 'open' in mac os or '/usr/bin/gnome-terminal' in ubuntu to open a new window and execute your command. 

As executing program in a new terminal window correctly is a little tricky thing, I create a script to let you open a new terminal window to execute your program in both Windows, Linux (ubuntu), Cygwin and Mac OS X, you can try it from: https://github.com/skywind3000/terminal.

## Credits
TODO