/*
 *	Gnu.xs --- GNU Readline wrapper module
 *
 *	$Id: Gnu.xs,v 1.2 1996-10-26 15:41:45 hayashi Exp $
 *
 *	Copyright (c) 1996 Hiroo Hayashi.  All rights reserved.
 *
 *	This program is free software; you can redistribute it and/or
 *	modify it under the same terms as Perl itself.
 */

#ifdef __cplusplus
extern "C" {
#endif
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#ifdef __cplusplus
}
#endif

#include <stdio.h>
#include <readline/readline.h>
#include <readline/history.h>

static char *preput = (char *)NULL;
static int
rl_insert_preput ()
{
  if (preput)
    rl_insert_text(preput);
  return 0;
}

MODULE = Term::ReadLine::Gnu		PACKAGE = Term::ReadLine::Gnu

char *
rl_readline(...)
	PROTOTYPE: ;$$
	CODE:
	{
	  static char *line_read =  (char *)NULL;
	  char *prompt;

	  prompt = items > 0 ? (char *)SvPV(ST(0), na) : (char *)NULL;
	  preput = items > 1 ? (char *)SvPV(ST(1), na) : (char *)NULL;
	  rl_startup_hook = rl_insert_preput;

	  if (line_read != NULL) {
	    free(line_read);
	    line_read = (char *)NULL;
	  }

	  RETVAL = line_read = readline(prompt);
	}
	OUTPUT:
	RETVAL

void
rl_add_history(...)
	PROTOTYPE: @
	CODE:
	{
	  register int i;
	  for (i = 0; i < items; i++)
	    add_history((char *)SvPV(ST(i), na));
	}

void
rl_GetHistory()
	PROTOTYPE:
	PPCODE:
	{
	  register HIST_ENTRY **the_list;
	  register int i;
     
	  the_list = history_list ();
	  if (the_list) {
	    EXTEND(sp, history_length);
	    for (i = 0; i < history_length; i++)
	      PUSHs(sv_2mortal(newSVpv(the_list[i]->line,0)));
	  }
	}

void
rl_SetHistory(...)
	PROTOTYPE: @
	CODE:
	{
	  register int i;
	  for (i = history_length - 1; i >= 0; i--) {
	    HIST_ENTRY *entry = remove_history (i);
	    if (!entry)
	      fprintf (stderr, "ReadLine: No such entry %d\n", i);
	    else {
	      free (entry->line);
	      free (entry);
	    }
	  }
	  for (i = 0; i < items; i++)
	    add_history((char *)SvPV(ST(i), na));
	}

void
rl_set_readline_name(name)
const char *	name;
	PROTOTYPE: $
	CODE:
	{
	  static char *readline_name = (char *)NULL;
	  size_t len;

	  if (readline_name != NULL) {
	    Safefree(readline_name);
	    readline_name = (char *)NULL;
	  }
	  len =  strlen(name)+1;
	  New(0, readline_name, len, char);
	  Copy(name, readline_name, len, char);
	  rl_readline_name = readline_name;
	}

void
rl_set_instream(fildes)
int	fildes;
	PROTOTYPE: $
	CODE:
	{
	  register FILE *fd;
	  if ((fd = fdopen(fildes, "r")) == NULL)
	    perror("Gnu.xs:rl_set_instream: cannot fdopen");
	  else
	    rl_instream = fd;
	}

void
rl_set_outstream(fildes)
int	fildes;
	PROTOTYPE: $
	CODE:
	{
	  register FILE *fd;
	  if ((fd = fdopen(fildes, "w")) == NULL)
	    perror("Gnu.xs:rl_set_outstream: cannot fdopen");
	  else
	    rl_outstream = fd;
	}

int
rl_read_history(...)
	PROTOTYPE: ;$$$
	CODE:
	{
	  char *filename;
	  int from, to;

	  filename = items > 0 ? (char *)SvPV(ST(0), na) : (char *)NULL;
	  from	   = items > 1 ? SvIV(ST(1)) :  0;
	  to	   = items > 2 ? SvIV(ST(2)) : -1;

	  RETVAL = ! read_history_range(filename, from, to);
	}
	OUTPUT:
	RETVAL

int
rl_write_history(...)
	PROTOTYPE: ;$
	CODE:
	{
	  char *filename;

	  filename = items > 0 ? (char *)SvPV(ST(0), na) : (char *)NULL;

	  RETVAL = ! write_history(filename);
	}
	OUTPUT:
	RETVAL
