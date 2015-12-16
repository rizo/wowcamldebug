(*
 * Copyright (C) <2003-2005> Stefano Zacchiroli <zack@bononia.it>
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

(* TODO
 * - add undo command (last)
 * - add side markers for brekpoints (cfr. agide)
 * - discover why current position highlight doesn't work on "let" keywords
 *   details: apparently it doesn't work on every keywords when it appears at
 *            the beginning of a line
 * - strange CTRL-C behaviour: "break_debugger" function is invoked once for
 *   each CTRL-C pressed, but ocamldebug prints "Interrupted" once the first
 *   time CTRL-C is pressed, twice the second one and so on ...
 * - better display of current event: when clicking away to print values is easy
 *   to forget where the current event was
 * - feedback of ocamldebug questions on gvim side
 *
 * TODO FIXME BUGS
 * - wowcamldebug can't distinguish between ocamldebug output and debugged
 *   program output. Programs writing on stdout one of the ocamldebug prompts
 *   (see variable "prompts" below) can mess up debugging status.
 *   I know no solutions for this bug yet, feel free to suggest one ...
 *)

open Printf

(** {2 Configuration} *)

let vim_init_rc = "wowcamldebug.vim"
let ocamldebug_cmd = "ocamldebug"
let gvim = "gvim"
let vim_server_name = "wowcamldebug_"

let debug = false (* debugging a tool that plan to execute a debugger, wow! *)

(** {2 Types and Accessors} *)

exception EOF_from of [ `Debugger | `Editor | `User ]
exception Module_not_found of string
exception Ignore_command

type debugger = {
  pid: int;
  input: out_channel;                     (* ocamldebug's input *)
  output_fd: Unix.file_descr;             (* ocamldebug's output *)
  module_map: (string, string) Hashtbl.t; (* mod_name -> file_name *)
}

type editor = {
  name: string;               (* vim server editor name *)
  suck_fd: Unix.file_descr;   (* socket with wowcamldebug: input channel *)
  suck_name: string;          (* socket with wowcamldebug: file name *)
}

type editor_command' =
  | Error of string (* error message. Shouldn't contain '\'' (quote) chars *)
  | Go of
      string * int * int *  (* file name, line, column *)
      int * int *           (* time, pc *)
      string option         (* message *)
  | Quit
type editor_command = editor_command' option  (* None = do nothing *)

let lookup_module debugger = Hashtbl.find debugger.module_map

let string_of_editor_command = function
  | None -> "NONE"
  | Some (Go (fname, line, col, time, pc, msg)) ->
      sprintf "edit(%s:%d,%d. Time:%d. PC:%d.)[%s]" fname line col time pc
        (match msg with Some msg -> msg | None -> "")
  | Some Quit -> "quit"
  | Some (Error errmsg) -> sprintf "error(%s)" errmsg

(** {2 Aux/Misc stuff} *)

let debug_print s = if debug then prerr_endline s
let warn s = prerr_endline ("W: " ^ s)
let strip_trailing_slash s = Pcre.replace ~pat:"/+$" s
let chomp s = Pcre.replace ~pat:"\\n+$" s

  (** default include (-I) directories *)
let stdlib_dir =
  let ic = Unix.open_process_in "ocamlc -where" in
  let dir = strip_trailing_slash (input_line ic) in
  ignore (Unix.close_process_in ic);
  dir
let std_includes = [ stdlib_dir; Sys.getcwd () ]

  (** ocamldebug's prompts handling *)
let prompts = [ "(ocd) "; "(y or n) " ] (* assumption: no one prefix another *)
let remove_trailing_prompt s =
  let rec aux = function
    | prompt :: tl when Pcre.pmatch ~pat:(Pcre.quote prompt ^ "$") s ->
        String.sub s 0 (String.length s - String.length prompt)
    | _ :: tl -> aux tl
    | [] -> assert false
  in
  aux prompts
let has_prompt s =
  List.exists (fun prompt -> Pcre.pmatch ~pat:(Pcre.quote prompt ^ "$") s)
    prompts

  (** directories juggling *)
let dir_contents dir =
  let handle = Unix.opendir dir in
  let rec aux acc =
    match (try Some (Unix.readdir handle) with End_of_file -> None) with
    | Some entry -> aux (entry :: acc)
    | None -> acc
  in
  let res = aux [] in
  Unix.closedir handle;
  res
let is_dir f =
  try
    (Unix.stat f).Unix.st_kind = Unix.S_DIR
  with Unix.Unix_error _ -> false
let is_reg f =
  try
    (Unix.stat f).Unix.st_kind = Unix.S_REG
  with Unix.Unix_error _ -> false

  (** parse -I arguments from argv expanding +foo notation *)
let parse_includes args =
  let rec aux = function
    | "-I" :: dir :: tl when is_dir dir ->
        strip_trailing_slash dir :: aux tl
    | "-I" :: dir :: tl when Pcre.pmatch ~pat:"^\\+" dir ->
        let dir = Pcre.replace ~pat:"^\\+" ~templ:(stdlib_dir ^ "/") dir in
        strip_trailing_slash dir :: aux tl
    | hd :: tl -> aux tl
    | _ -> []
  in
  aux args

  (** build from argv a pair <ocamldebug arguments, files to be sourced> *)
let parse_debugger_args () =
  if Array.length Sys.argv = 1
     || Sys.argv.(1) = "-help" || Sys.argv.(1) = "--help"
  then begin
    print_endline "Usage: wowcamldebug <executable> [<arg> [...]]";
    print_newline ();
    print_endline "Arguments are the usual ocamldebug ones:";
    ignore (Sys.command "ocamldebug -help");
    print_newline ();
    print_endline "In addition you can also use:";
    print_endline "  -source <filename>   'source' filename on startup";
    exit 1
  end else
    let args = ref [] in
    let scripts = ref [] in
    let ignore_next = ref false in
    Array.iteri
      (fun idx arg ->
        if !ignore_next then
          ignore_next := false
        else if idx <> 0 then
          match arg with
          | "-source" ->
              (* add given script to scripts and don't pass -script to
               * ocamldebug *)
              ignore_next := true;
              scripts := Sys.argv.(idx + 1) :: !scripts
          | "-cd" ->  (* change cwd and pass -cd argoment to ocamldebug too *)
              ignore_next := true;
              let dir = Sys.argv.(idx + 1) in
              Unix.chdir dir;
              args := dir :: "-cd" :: !args
          | _ -> args := arg :: !args)
      Sys.argv;
    (List.rev !args, List.rev !scripts)

  (** check if a fd can be read without blocking *)
let is_readable fd =
  match Unix.select [fd] [] [] 0. with
  | (fd_set, _, _) when List.mem fd fd_set -> true
  | _ -> false

(** {2 Debugger interaction} *)

let read_til_prompt =
  let buf = Buffer.create 1024 in
  let buf2len = 1024 in
  let buf2 = String.create buf2len in
  fun debugger ->
    Buffer.clear buf;
    (try
      while true do
        let bytes = Unix.read debugger.output_fd buf2 0 buf2len in
        (* Assumption: (read() = 0) -> (ocamldebug is dead) I don't know if
         * there are better ways to test for ocamldebug death *)
        if bytes = 0 then raise (EOF_from `Debugger);
        Buffer.add_substring buf buf2 0 bytes;
        let data = Buffer.contents buf in
        if has_prompt data then raise Exit
      done
    with Exit -> ());
    Buffer.contents buf

let create_module_map args =
  let include_dirs = parse_includes args in
  let include_dirs = std_includes @ include_dirs in
  let module_map = Hashtbl.create 1024 in
  List.iter
    (fun dir -> (* fill module names -> file names map *)
      List.iter
        (fun basename ->
          let path = dir ^ "/" ^ basename in
          if is_reg path && Pcre.pmatch ~pat:"\\.ml$" basename then
            let module_name =
              String.capitalize (Pcre.extract ~pat:"^(.*)\\.ml$" basename).(1)
            in
            debug_print (sprintf "Adding mapping %s -> %s" module_name path);
            Hashtbl.add module_map module_name path)
        (dir_contents dir))
    include_dirs;
  module_map

let start_debugger args =
  let cmdline = ocamldebug_cmd ^ " " ^ String.concat " " args in
  debug_print ("Starting debugger; cmdline = " ^ cmdline);
  let (dbg_pid, dbg_out, dbg_in) =
      (* ocamldebug is moved to a process group of his own so that foreground
       * process group contains just wowcamldebug and SIGINTs (CTRL-Cs) are not
       * deliverd to him *)
    WowUnix.open_process cmdline
  in
  let output_fd = Unix.descr_of_in_channel dbg_out in
  let module_map = create_module_map args in
  let debugger = {
    pid = dbg_pid;
    input = dbg_in;
    output_fd = output_fd;
    module_map = module_map;
  } in
  print_string (read_til_prompt debugger);
  flush stdout;
  debugger

let kill_debugger debugger = ()

let send_debugger_command cmd debugger =
  output_string debugger.input (cmd ^ "\n");
  flush debugger.input;
  read_til_prompt debugger

let time_line_RE =
  Pcre.regexp
    ".*(Time\\s+:\\s+(\\d+)\\s+-\\s+pc\\s+:\\s+(\\d+).*module\\s+(\\w+))$"
let loc_line_RE = Pcre.regexp "^(\\d+)\\s(.*)<\\|[ab]\\|>(.*)$"

let parse_debugger_answer debugger s =
  let lines = Pcre.split ~pat:"\n" (remove_trailing_prompt s) in
  let rec parse_module = function
    | line :: rest ->
        (try
          let subs = Pcre.extract ~rex:time_line_RE line in
          let (time, pc, mod_name) =
            try
              int_of_string subs.(2), int_of_string subs.(3), subs.(4)
            with Failure "int_of_string" -> raise Exit
          in
          (try
            (None, lookup_module debugger mod_name, rest, time, pc)
          with Not_found -> raise (Module_not_found mod_name))
        with Not_found -> parse_module rest)
    | _ -> raise Exit
  in
  let rec parse_position = function
    | line :: rest ->
        (try
          let loc_line_subs = Pcre.extract ~rex:loc_line_RE line in
          let line = int_of_string loc_line_subs.(1) in
          let col = String.length loc_line_subs.(2) + 1 in
          line, col
        with Not_found | Failure "int_of_string" -> parse_position rest)
    | _ -> raise Exit
  in
  try
    let (msg, file, rest, time, pc) = parse_module lines in
    let (line, col) = parse_position rest in
    Some (Go (file, line, col, time, pc, msg))
  with
  | Module_not_found mod_name ->
      Some (Error (sprintf "Source file for module %s not found" mod_name))
  | Exit ->
      debug_print "Can't parse ocamldebug output, ignoring it";
      None

(** {2 Editor interaction} *)

let send_editor_keys keys editor =
  Sys.command (sprintf "%s --servername '%s' --remote-send '%s'"
    gvim editor.name (String.concat "" keys))

let start_editor () =
  let id = Random.int 1024 in
  let name = vim_server_name ^ string_of_int id in
  let suck_fd = Unix.socket Unix.PF_UNIX Unix.SOCK_DGRAM 0 in
  let suck_name = Filename.temp_file "wowcamldebug" "" in
  Unix.unlink suck_name;  (* TODO FIXME insecure *)
  Unix.bind suck_fd (Unix.ADDR_UNIX suck_name);
  let vim_init_commands = [
    sprintf "+let wowcamldebug_socket=\\\"%s\\\"" suck_name;
    sprintf "+runtime %s" vim_init_rc;
  ] in
  let init_commands = 
    String.concat " "
      (List.map (fun cmd -> "\"" ^ cmd ^ "\"") vim_init_commands)
  in
  let cmdline = sprintf "%s %s --servername '%s'" gvim init_commands name in
  debug_print ("Starting editor; cmdline = " ^ cmdline);
  let exit_code = Sys.command  cmdline in
  if exit_code <> 0 then failwith (sprintf "Can't start '%s' properly" gvim);
  {
    name = name;
    suck_name = suck_name;
    suck_fd = suck_fd;
  }

let send_editor_command command editor =
  match command with
  | Some cmd ->
      let keys =
        match cmd with
        | Go (fname, line, col, time, pc, msg) ->
            [ sprintf ":view +%d %s<CR>" line
                (Pcre.replace ~pat:" " ~templ:"\\ " fname);
              sprintf ":syntax match OCamlDebug_PC \"\\%%%dl.*\"<CR>" line;
              sprintf ":let g:wowcamldebug_time = %d<CR>" time;
              sprintf ":let g:wowcamldebug_pc = %d<CR>" pc;
              sprintf "0%dl" (col - 1)
            ] @
            (match msg with
            | None -> []
            | Some msg -> [ sprintf ":echo \"%s\"<CR>" msg ])
        | Quit -> [ ":q!<CR>" ]
        | Error errmsg -> [ sprintf ":echoe \"%s\"<CR>" errmsg ]
      in
      if send_editor_keys keys editor <> 0 then
        warn "Can't send command to editor properly"
  | None -> ()

let kill_editor editor =
  send_editor_command (Some Quit) editor;
  Unix.unlink editor.suck_name

(** {2 User interaction} *)

let get_user_command () =
  try
    input_line stdin
  with End_of_file -> raise (EOF_from `User)

let get_editor_command =
  let buflen = 1024 in
  let buf = String.create buflen in
  fun editor ->
    try
      let bytes = Unix.recv editor.suck_fd buf 0 buflen [] in
      let msg = String.sub buf 0 bytes in
      print_string msg;
      flush stdout;
      chomp msg
    with End_of_file -> raise (EOF_from `Editor)

(** {2 Main loop} *)

let init () =
  Sys.catch_break true;
  Random.self_init ()

let resync answer debugger editor =
  print_string answer;
  flush stdout;
  let editor_cmd = parse_debugger_answer debugger answer in
  debug_print
    ("Sending to editor command: " ^ string_of_editor_command editor_cmd);
  send_editor_command editor_cmd editor

let do_debugger_cmd debugger_cmd debugger editor =
  debug_print ("Sending to debugger command: " ^ debugger_cmd);
  let answer = send_debugger_command debugger_cmd debugger in
  resync answer debugger editor

  (* sends a CTRL-C to ocamldebug and resync *)
let break_debugger debugger editor =
  debug_print "Sending CTRL-C to debugger and resyncing";
  Unix.kill debugger.pid Sys.sigint;
  let answer = read_til_prompt debugger in
  resync answer debugger editor

let run_scripts debugger editor =
  let run_script fname =
    print_endline (sprintf "Sourcing script %s ..." fname); flush stdout;
    do_debugger_cmd (sprintf "source \"%s\"" fname) debugger editor
  in
  List.iter run_script

let main () =
  init ();
  let (args, scripts) = parse_debugger_args () in
  let debugger = start_debugger args in
  let editor = start_editor () in
  run_scripts debugger editor scripts;
  try
    while true do
      try
        debug_print "Waiting for command from (user | editor)";
        let (readables, _, _) =
          Unix.select [Unix.stdin; editor.suck_fd] [] [] (-1.)
        in
        if List.mem Unix.stdin readables then begin (* input from stdin *)
          try
            do_debugger_cmd (get_user_command ()) debugger editor
          with
          | EOF_from `User -> do_debugger_cmd "quit" debugger editor
          | Ignore_command -> ()
        end;
        if List.mem editor.suck_fd readables then begin (* input from editor *)
          do_debugger_cmd (get_editor_command editor) debugger editor
        end
      with Sys.Break -> break_debugger debugger editor
    done
  with
  | EOF_from `Debugger -> kill_editor editor
  | EOF_from `Editor -> kill_debugger debugger

  (** {Main} *)

let _ = main ()

