/*
 *	Gnu.xs --- GNU Readline wrapper module
 *
 *	$Id: Gnu.xs,v 1.6 1996-11-19 15:08:35 hayashi Exp $
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

extern char *xmalloc ();	/* defined in libreadline.a */

static char *
dupstr (s)			/* duplicate string */
     char *s;
{
  char *r;
     
  r = xmalloc (strlen (s) + 1);
  strcpy (r, s);
  return (r);
}
     
static char *preput_str = (char *)NULL;
static int
rl_insert_preput ()
{
  if (preput_str)
    rl_insert_text(preput_str);
  return 0;
}

/*
 * call a perl function as rl_completion_entry_function
 */
static SV * completion_entry_function = (SV *)NULL;

static char *
completion_entry_function_lapper(text, state)
     char *text;
     int state;
{
  dSP;
  int count;
  SV *match;
  char *str;
  
  ENTER;
  SAVETMPS;

  PUSHMARK(sp);
  XPUSHs(sv_2mortal(newSVpv(text, 0)));
  XPUSHs(sv_2mortal(newSViv(state)));
  PUTBACK;

  count = perl_call_sv(completion_entry_function, G_SCALAR);

  SPAGAIN;

  if (count != 1)
    croak("Internal error\n");

  match = POPs;
  str = SvOK(match) ? dupstr(SvPV(match, na)) : (char *)NULL;

  PUTBACK;
  FREETMPS;
  LEAVE;
  return str;
}

/*
 * call a perl function as rl_attempted_completion_function
 */
static SV * attempted_completion_function = (SV *)NULL;

static char **
attempted_completion_function_lapper(text, start, end)
     char *text;
     int start, end;
{
  dSP;
  int count;
  char **matches;
  
  ENTER;
  SAVETMPS;

  PUSHMARK(sp);
  XPUSHs(sv_2mortal(newSVpv(text, 0)));
  XPUSHs(sv_2mortal(newSVpv(rl_line_buffer, 0)));
  XPUSHs(sv_2mortal(newSViv(start)));
  XPUSHs(sv_2mortal(newSViv(end)));
  PUTBACK;

  count = perl_call_sv(attempted_completion_function, G_ARRAY);

  SPAGAIN;

  matches = (char **)NULL;

  if (count > 1) {
    int i;

    matches = (char **)xmalloc (sizeof(char *) * (count + 1));
    matches[count] = (char *)NULL;
    for (i = count - 1; i >= 0; i--)
      matches[i] = dupstr(POPp);

  } else if (count == 1) {	/* return NULL if undef is returned */
    SV *v = POPs;

    if (SvOK(v)) {
      matches = (char **)xmalloc (sizeof(char *) * 2);
      matches[0] = dupstr(SvPV(v, na));
      matches[1] = (char *)NULL;
    }
  }

  PUTBACK;
  FREETMPS;
  LEAVE;

  return matches;
}

MODULE = Term::ReadLine::Gnu		PACKAGE = Term::ReadLine::Gnu

void
_rl_readline(prompt = (char *)NULL, preput = (char *)NULL)
	char *prompt
	char *preput
	PROTOTYPE: ;$$
	CODE:
	{
	  char *line_read;

	  /*
	   * set default input string using readline() hook
	   */
	  preput_str = preput;
	  rl_startup_hook = rl_insert_preput;

	  /*
	   * call readline()
	   */
	  line_read = readline(prompt);

	  /*
	   * return undef if readline() returns NULL
	   */
	  ST(0) = sv_newmortal();
	  if (line_read != (char *)NULL) {
	    sv_setpv(ST(0), line_read);
	    free(line_read);
	  }
	}

void
history_expand(line)
	char *line
	PROTOTYPE: $
	PPCODE:
	{
	  char *expansion;
	  int result;

	  result = history_expand(line, &expansion);
	  EXTEND(sp, 2);
	  PUSHs(sv_2mortal(newSViv(result)));
	  PUSHs(sv_2mortal(newSVpv(expansion, 0)));
	  free(expansion);
	}

int
_stifle_history(i)
	SV *i
	PROTOTYPE: $
	CODE:
	{
	  if (SvOK(i)) {
	    int max = SvIV(i);
	    stifle_history(max);
	    RETVAL = max;
	  } else {
	    RETVAL = unstifle_history();
	  }
	}
	OUTPUT:
	RETVAL

void
_rl_add_history(...)
	PROTOTYPE: @
	CODE:
	{
	  register int i;
	  for (i = 0; i < items; i++)
	    add_history((char *)SvPV(ST(i), na));
	}

void
_rl_GetHistory()
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
_rl_SetHistory(...)
	PROTOTYPE: @
	CODE:
	{
	  register int i;
	  /*
	   * clear whole history table
	   * clear from tail for efficiency
	   */
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
_rl_set_readline_name(name)
	const char *	name
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
_rl_store_basic_word_break_characters(str)
	const char *	str
	PROTOTYPE: $
	CODE:
	{
	  static char *bwbc = (char *)NULL;
	  size_t len;

	  if (bwbc != NULL) {
	    Safefree(bwbc);
	    bwbc = (char *)NULL;
	  }
	  len =  strlen(str)+1;
	  New(0, bwbc, len, char);
	  Copy(str, bwbc, len, char);
	  rl_basic_word_break_characters = bwbc;
	}

void
_rl_set_instream(fildes)
	int	fildes
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
_rl_set_outstream(fildes)
	int	fildes
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
_rl_read_history(filename = (char *)NULL, from = 0, to = -1)
	char *filename
	int from
	int to
	PROTOTYPE: ;$$$
	CODE:
	{
	  RETVAL = ! read_history_range(filename, from, to);
	}
	OUTPUT:
	RETVAL

int
_rl_write_history(filename = (char *)NULL)
	char *filename
	PROTOTYPE: ;$
	CODE:
	{
	  RETVAL = ! write_history(filename);
	}
	OUTPUT:
	RETVAL

void
rl_parse_and_bind(line)
	char *line
	PROTOTYPE: $

void
_rl_store_completion_entry_function(fn)
	SV *	fn
	CODE:
	{
	  if (! SvTRUE(fn)
	      || (SvPOK(fn) && (strcmp("filename", SvPV(fn, na)) == 0))) {
	    rl_completion_entry_function
	      = (Function *)filename_completion_function;
	  } else if (SvPOK(fn) && (strcmp("username", SvPV(fn, na)) == 0)) {
	    rl_completion_entry_function
	      = (Function *)username_completion_function;
	  } else {
	    if (completion_entry_function == (SV *)NULL)
	      completion_entry_function = newSVsv(fn);
	    else
	      SvSetSV(completion_entry_function, fn);

	    rl_completion_entry_function
	      = (Function *)completion_entry_function_lapper;
	  }
	}

void
_rl_store_attempted_completion_function(fn)
	SV *	fn
	CODE:
	{
	  if (! SvTRUE(fn)) {
	    rl_attempted_completion_function = (CPPFunction *)NULL;
	  } else {
	    if (attempted_completion_function == (SV *)NULL)
	      attempted_completion_function = newSVsv(fn);
	    else
	      SvSetSV(attempted_completion_function, fn);

	    rl_attempted_completion_function
	      = (CPPFunction *)attempted_completion_function_lapper;
	  }
	}

MODULE = Term::ReadLine::Gnu		PACKAGE = Term::ReadLine

void
completion_matches(text, fn)
	char * text
	SV * fn
	PPCODE:
	{
	  char **matches;
	  if (! SvTRUE(fn)
	      || (SvPOK(fn) && (strcmp("filename", SvPV(fn, na)) == 0))) {
	    matches = completion_matches(text, filename_completion_function);
	  } else if (SvPOK(fn) && (strcmp("username", SvPV(fn, na)) == 0)) {
	    matches = completion_matches(text, username_completion_function);
	  } else {
	    /* use completion_entry_function temporarily */
	    SV * save = completion_entry_function;
	    if (save == (SV *)NULL)
	      completion_entry_function = newSVsv(fn);
	    else
	      SvSetSV(completion_entry_function, fn);
	    matches = completion_matches(text,
					 completion_entry_function_lapper);
	    completion_entry_function = save;
	  }
	  if (matches != NULL) {
	    int i, count;

	    /* count number of entries */
	    for (count = 0; matches[count]; count++)
	      ;

	    EXTEND(sp, count);
	    for (i = 0; i < count; i++) {
	      PUSHs(sv_2mortal(newSVpv(matches[i], 0)));
	      free(matches[i]);
	    }
	    free(matches);
	  } else {
	    /* return null list */
	  }
	}
