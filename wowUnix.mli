(*
 * Copyright (C) <2003-2004> Stefano Zacchiroli <zack@bononia.it>
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

  (** "setpgid" syscall binding
   * @param pid target pid
   * @param pgid new pgid
   * @raise Failure if syscall fails
   *)
external setpgid: int -> int -> unit = "ml_wow_setpgid"

  (** "setpgrp" syscall binding
  * @raise Failure if syscall fails
  *)
val setpgrp: unit -> unit

  (** Slightly modified version of Unix.open_process: opened process is detached
   * from current process group and its pid is returned along with I/O channels
   *)
val open_process: string -> int * in_channel * out_channel

