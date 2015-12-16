"
" Copyright (C) <2003-2005> Stefano Zacchiroli <zack@bononia.it>
"
" WOWcamldebug - WOnderful (g)Vim oCAML DEBUGger
"
" This program is free software; you can redistribute it and/or modify
" it under the terms of the GNU General Public License as published by
" the Free Software Foundation; either version 2 of the License, or
" (at your option) any later version.
" 
" This program is distributed in the hope that it will be useful,
" but WITHOUT ANY WARRANTY; without even the implied warranty of
" MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
" GNU General Public License for more details.
" 
" You should have received a copy of the GNU General Public License
" along with this program; if not, write to the Free Software
" Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
"

highlight OCamlDebug_PC guibg=#a0a0ff"; 

let g:wowcamldebug_time = 0
let g:wowcamldebug_pc = 0

set laststatus=2
set mousemodel=popup_setpos
set nomodifiable
set statusline=%<%t\ %h%m%r%=%([\ Time:\ %{wowcamldebug_time}\ -\ PC:\ %{wowcamldebug_pc}\ ]%)%2.(\ %)%-14.(%l,%c%V%)

" Key bindings
nmapclear
nmap <F2> :call Wowcamldebug_go0()<CR>
nmap <F3> :call Wowcamldebug_print()<CR>
nmap <C-F3> :call Wowcamldebug_display()<CR>
nmap <F6> :call Wowcamldebug_break()<CR>
nmap <F7> :call Wowcamldebug_previous()<CR>
nmap <C-F7> :call Wowcamldebug_backstep()<CR>
nmap <C-F8> :call Wowcamldebug_step()<CR>
nmap <F8> :call Wowcamldebug_next()<CR>
nmap <F9> :call Wowcamldebug_run()<CR>
nmap <C-F10> :call Wowcamldebug_quit()<CR>

" Menu
nmenu &Camldebug.&Next<Tab>F8 :call Wowcamldebug_next()<CR>
nmenu &Camldebug.&Previous<Tab>F7 :call Wowcamldebug_previous()<CR>
nmenu &Camldebug.&Step<Tab>C-F8 :call Wowcamldebug_step()<CR>
nmenu &Camldebug.&Backstep<Tab>C-F7 :call Wowcamldebug_backstep()<CR>
nmenu &Camldebug.-Sep1- :<CR>
nmenu &Camldebug.&Run<Tab>F9 :call Wowcamldebug_run()<CR>
nmenu &Camldebug.&Go\ 0<Tab>F2 :call Wowcamldebug_go0()<CR>
nmenu &Camldebug.&Finish :call Wowcamldebug_finish()<CR>
nmenu &Camldebug.-Sep2- :<CR>
nmenu &Camldebug.&Add\ breakpoint<Tab>F6 :call Wowcamldebug_break()<CR>
nmenu &Camldebug.&Delete\ all\ breakpoints :call Wowcamldebug_delete_all()<CR>
nmenu &Camldebug.-Sep3- :<CR>
nmenu &Camldebug.&Print\ (deep)<Tab>F3 :call Wowcamldebug_print()<CR>
nmenu &Camldebug.Print\ (shallow)<Tab>C-F3 :call Wowcamldebug_display()<CR>
nmenu &Camldebug.-Sep4- :<CR>
nmenu &Camldebug.&Quit<Tab>C-F10 :call Wowcamldebug_quit()<CR>

" PopUp Menu
nmenu PopUp.-Sep1- :<CR>
nmenu PopUp.&Camldebug.&Add\ breakpoint<Tab>F6 :call Wowcamldebug_break()<CR>
nmenu PopUp.&Camldebug.&Print\ (deep) :call Wowcamldebug_print()<CR>
nmenu PopUp.&Camldebug.&Print\ (shallow) :call Wowcamldebug_display()<CR>

" ToolBar
aunmenu ToolBar
nmenu icon=wowcamldebug_go0 1.290 ToolBar.WowGo0 :call Wowcamldebug_go0()<CR>
nmenu 1.290 ToolBar.-sepZ0- <nop>
nmenu icon=wowcamldebug_print 1.290 ToolBar.WowPrint :call Wowcamldebug_print()<CR>
nmenu icon=wowcamldebug_display 1.290 ToolBar.WowDisplay :call Wowcamldebug_display()<CR>
nmenu 1.290 ToolBar.-sepZ1- <nop>
nmenu icon=wowcamldebug_break 1.290 ToolBar.WowBreak :call Wowcamldebug_break()<CR>
nmenu 1.290 ToolBar.-sepZ2- <nop>
nmenu icon=wowcamldebug_prev 1.290 ToolBar.WowPrevious :call Wowcamldebug_previous()<CR>
nmenu icon=wowcamldebug_back 1.290 ToolBar.WowBackstep :call Wowcamldebug_backstep()<CR>
nmenu icon=wowcamldebug_step 1.290 ToolBar.WowStep :call Wowcamldebug_step()<CR>
nmenu icon=wowcamldebug_next 1.290 ToolBar.WowNext :call Wowcamldebug_next()<CR>
nmenu 1.290 ToolBar.-sepZ3- <nop>
nmenu icon=wowcamldebug_run 1.290 ToolBar.WowRun :call Wowcamldebug_run()<CR>
nmenu 1.290 ToolBar.-sepZ4- <nop>
nmenu icon=wowcamldebug_quit 1.290 ToolBar.WowQuit :call Wowcamldebug_quit()<CR>

" ToolBar's tooltips
tmenu ToolBar.WowBackstep Step backward
tmenu ToolBar.WowBreak Add breakpoint
tmenu ToolBar.WowDisplay Print value (shallow printing)
tmenu ToolBar.WowGo0 Go to time 0 (beginning)
tmenu ToolBar.WowNext Step forward (skip over function calls)
tmenu ToolBar.WowPrevious Step backward (skip over function calls)
tmenu ToolBar.WowPrint Print value (deep printing)
tmenu ToolBar.WowQuit Quit both gvim and ocamldebug
tmenu ToolBar.WowRun Run
tmenu ToolBar.WowStep Step forward

" Misc functions

  " return identifier at cursor position
fun Wowcamldebug_get_ident_at_cursor()
  let line = getline(line("."))
  let len = strlen(line)
  let curpos = col(".")
  if line[curpos - 1] !~ "\\w"
    throw "No identifier at cursor"
  endif
  let l = curpos
  let r = curpos
  while l - 2 >= 0
    if line[l - 2] !~ "\\w"
      break
    endif
    let l = l - 1
  endwhile
  while r <= len
    if line[r] !~ "\\w"
      break
    endif
    let r = r + 1
  endwhile
  return strpart(line, l - 1, r - l + 1)
endfun

" Above referenced functions implementation

fun Wowcamldebug_break__()
  let basename = substitute(bufname(""), '^.*/', '', '')
  let modname = substitute(basename, '\.[^.]\+$', '', '')
  let Modname = toupper(strpart(modname, 0, 1)) . strpart(modname, 1)
  return Modname
endfun

fun Wowcamldebug_go0__()
  let g:wowcamldebug_time = 0
  let g:wowcamldebug_pc = 0
"   enew
endfun

if !has("python")
  " Functions (using external "wowtell" command)
  if !executable("wowtell")
    echoe "wowcamldebug: neither python support nor external 'wowtell' utility found"
    echoe "wowcamldebug: disabling 'Camldebug' menus"
    amenu disable &Camldebug.*
    amenu disable PopUp.&Camldebug.*
    finish
  endif
  fun Wowcamldebug_help()
    call system("wowtell help " . g:wowcamldebug_socket)
  endfun
  fun Wowcamldebug_next()
    call system("wowtell next " . g:wowcamldebug_socket)
  endfun
  fun Wowcamldebug_previous()
    call system("wowtell prev " . g:wowcamldebug_socket)
  endfun
  fun Wowcamldebug_step()
    call system("wowtell step " . g:wowcamldebug_socket)
  endfun
  fun Wowcamldebug_backstep()
    call system("wowtell backstep " . g:wowcamldebug_socket)
  endfun
  fun Wowcamldebug_run()
    call system("wowtell run " . g:wowcamldebug_socket)
  endfun
  fun Wowcamldebug_go0()
    call Wowcamldebug_go0__()
    call system("wowtell 'go 0' " . g:wowcamldebug_socket)
  endfun
  fun Wowcamldebug_finish()
    call system("wowtell finish " . g:wowcamldebug_socket)
  endfun
  fun Wowcamldebug_break()
    let Modname = Wowcamldebug_break__()
    let cmdline = "wowtell \"break @ " . Modname . " " . line(".") . " " . col(".") "\" " . g:wowcamldebug_socket
    call system(cmdline)
  endfun
  fun Wowcamldebug_delete_all()
    call system("wowtell delete " . g:wowcamldebug_socket)
  endfun
  fun Wowcamldebug_quit()
    call system("wowtell quit " . g:wowcamldebug_socket)
    call system("wowtell y " . g:wowcamldebug_socket)
  endfun
  fun Wowcamldebug_print()
    let ident = Wowcamldebug_get_ident_at_cursor()
    call system("wowtell 'print " . ident . "' " . g:wowcamldebug_socket)
  endfun
  fun Wowcamldebug_display()
    let ident = Wowcamldebug_get_ident_at_cursor()
    call system("wowtell 'display " . ident . "' " . g:wowcamldebug_socket)
  endfun
  finish  " to avoid vim parsing python code when python isn't available
else  " has("python")
python << EOF

import socket
import sys
import vim

wowcamldebug_socket = None

def wowtell(msg, file):
    global wowcamldebug_socket
    if wowcamldebug_socket == None:
        wowcamldebug_socket = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
        wowcamldebug_socket.connect((file))
    wowcamldebug_socket.send(msg + "\n")

EOF
  " Functions (using python from vim-python)
  fun Wowcamldebug_help()
    python wowtell("help", vim.eval("g:wowcamldebug_socket"))
  endfun
  fun Wowcamldebug_next()
    python wowtell("next", vim.eval("g:wowcamldebug_socket"))
  endfun
  fun Wowcamldebug_previous()
    python wowtell("previous", vim.eval("g:wowcamldebug_socket"))
  endfun
  fun Wowcamldebug_step()
    python wowtell("step", vim.eval("g:wowcamldebug_socket"))
  endfun
  fun Wowcamldebug_backstep()
    python wowtell("backstep", vim.eval("g:wowcamldebug_socket"))
  endfun
  fun Wowcamldebug_run()
    python wowtell("run", vim.eval("g:wowcamldebug_socket"))
  endfun
  fun Wowcamldebug_go0()
    call Wowcamldebug_go0__()
    python wowtell("go 0", vim.eval("g:wowcamldebug_socket"))
  endfun
  fun Wowcamldebug_finish()
    python wowtell("finish", vim.eval("g:wowcamldebug_socket"))
  endfun
  fun Wowcamldebug_break()
    let Modname = Wowcamldebug_break__()
    let cmd = "break @ " . Modname . " " . line(".") . " " . col(".")
    python wowtell(vim.eval("cmd"), vim.eval("g:wowcamldebug_socket"))
  endfun
  fun Wowcamldebug_delete_all()
    python wowtell("delete", vim.eval("g:wowcamldebug_socket"))
  endfun
  fun Wowcamldebug_quit()
    python wowtell("quit", vim.eval("g:wowcamldebug_socket"))
    python wowtell("y", vim.eval("g:wowcamldebug_socket"))
  endfun
  fun Wowcamldebug_print()
    python wowtell("print " + vim.eval("Wowcamldebug_get_ident_at_cursor()"), vim.eval("g:wowcamldebug_socket"))
  endfun
  fun Wowcamldebug_display()
    python wowtell("display " + vim.eval("Wowcamldebug_get_ident_at_cursor()"), vim.eval("g:wowcamldebug_socket"))
  endfun
endif

