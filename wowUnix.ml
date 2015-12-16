(*
 * Copyright (C) <2003-2008> Stefano Zacchiroli <zack@bononia.it>
 *
 * WOWcamldebug - WOnderful (g)Vim oCAML DEBUGger
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 *
 *
 * WOWcamldebug is a front end which permits interaction between the
 * ocaml debugger (ocamldebug) and the (g)vim editor.
 *)

external setpgid: int -> int -> unit = "ml_wow_setpgid"

let setpgrp () = setpgid 0 0

let open_process cmdline =
  let (in_read, in_write) = Unix.pipe () in
  let (out_read, out_write) = Unix.pipe () in
  let inchan = Unix.in_channel_of_descr in_read in
  let outchan = Unix.out_channel_of_descr out_write in
  let child_pid =
    match Unix.fork () with
    | 0 ->  (* child *)
        setpgrp (); (* move child to a process group of its own *)
        if out_read <> Unix.stdin then begin
          Unix.dup2 out_read Unix.stdin;
          Unix.close out_read
        end;
        if in_write <> Unix.stdout then begin
          Unix.dup2 in_write Unix.stdout;
          Unix.close in_write
        end;
        List.iter Unix.close [in_read; out_write];
        Unix.execv "/bin/sh" [| "/bin/sh"; "-c"; cmdline |];
        exit 127
    | child_pid ->  (* parent *)
        child_pid
  in
  Unix.close out_read;
  Unix.close in_write;
  (child_pid, inchan, outchan)

