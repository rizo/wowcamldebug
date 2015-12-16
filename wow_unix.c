/*
	Copyright (C) <2003-2008> Stefano Zacchiroli <zack@bononia.it>

	WOWcamldebug - WOnderful (g)Vim oCAML DEBUGger

	This program is free software; you can redistribute it and/or
	modify it under the terms of the GNU General Public License as
	published by the Free Software Foundation; either version 2 of
	the License, or (at your option) any later version.

	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public
	License along with this program; if not, write to the Free
	Software Foundation, Inc., 59 Temple Place, Suite 330, Boston,
	MA  02111-1307  USA


	WOWcamldebug is a front end which permits interaction between
	the ocaml debugger (ocamldebug) and the (g)vim editor.
*/

#include <errno.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

#include <caml/fail.h>
#include <caml/mlvalues.h>

#define	ERRMSG_LEN	512

extern int errno;

CAMLprim value ml_wow_setpgid(value pid, value pgid) {
	static char errmsg[ERRMSG_LEN];
	if (setpgid(Int_val(pid), Int_val(pgid)) == -1) {
		snprintf(errmsg, ERRMSG_LEN,
				"WowUnix.setpgid failed: %s",
				strerror(errno));
		failwith(errmsg);
	}
	return Val_unit;
}

