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
 *)

let send msg file =
  let fd = Unix.socket Unix.PF_UNIX Unix.SOCK_DGRAM 0 in
  Unix.connect fd (Unix.ADDR_UNIX file);
  ignore (Unix.send fd msg 0 (String.length msg) [])

let _ =
  try
    send (Sys.argv.(1) ^ "\n") Sys.argv.(2)
  with Invalid_argument "Array.get" ->
    print_endline "Usage: wowtell <ocd_command> <wow_socket>";
    exit 1

