/*
 *	Gnu.xs --- GNU Readline wrapper module
 *
 *	$Id: Gnu.xs,v 1.10 1996-12-05 14:05:27 hayashi Exp $
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

/*
 *	string variable table for _rl_store_int(), _rl_fetch_int()
 */
static struct str_vars {
  char *buf;
  char **var;
  int readonly;
} str_tbl[] = {
  /* When you change length of rl_line_buffer, change
     rl_line_buffer_len also. */
  (char *)NULL,	&rl_line_buffer, 0,			/* 0 */
  (char *)NULL,	&rl_library_version, 1,			/* 1 */
  (char *)NULL,	&rl_readline_name, 0,			/* 2 */

  (char *)NULL,	&rl_basic_word_break_characters, 0,	/* 3 */
  (char *)NULL, &rl_basic_quote_characters, 0,		/* 4 */
  (char *)NULL,	&rl_completer_word_break_characters, 0,	/* 5 */
  (char *)NULL,	&rl_completer_quote_characters, 0,	/* 6 */
  (char *)NULL,	&rl_filename_quote_characters, 0,	/* 7 */
  (char *)NULL,	&rl_special_prefixes, 0,		/* 8 */

  (char *)NULL,	&history_no_expand_chars, 0,		/* 9 */
  (char *)NULL,	&history_search_delimiter_chars, 0	/* 10 */
};

/*
 *	integer variable table for _rl_store_int(), _rl_fetch_int()
 */
extern int rl_completion_query_items;
extern int rl_ignore_completion_duplicates;
extern int rl_line_buffer_len;

static struct int_vars {
  int *var;
  int charp;
} int_tbl[] = {
  &rl_line_buffer_len, 0,				/* 0 */
  &rl_point, 0,						/* 1 */
  &rl_end, 0,						/* 2 */
  &rl_mark, 0,						/* 3 */
  &rl_done, 0,						/* 4 */
  &rl_pending_input, 0,					/* 5 */

  &rl_completion_query_items, 0,			/* 6 */
  &rl_completion_append_character, 0,			/* 7 : int */
  &rl_ignore_completion_duplicates, 0,			/* 8 */
  &rl_filename_completion_desired, 0,			/* 9 */
  &rl_filename_quoting_desired, 0,			/* 10 */
  &rl_inhibit_completion, 0,				/* 11 */

  &history_base, 0,					/* 12 */
  &history_length, 0,					/* 13 */
  &history_offset, 0,					/* 14 */
  (int *)&history_expansion_char, 1,			/* 15 */
  (int *)&history_subst_char, 1,			/* 16 */
  (int *)&history_comment_char, 1,			/* 17 */
  &history_quotes_inhibit_expansion, 0			/* 18 */
};

/* from GNU Readline:xmalloc.c */
extern char *xmalloc (int);
#ifdef HAVE_READLINE_2_1
extern char *xfree (char *);
#else
void
xfree (string)
     char *string;
{
  if (string)
    free (string);
}
#endif

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
	    xfree(line_read);
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
	  xfree(expansion);
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
	      xfree(entry->line);
	      xfree((char *)entry);
	    }
	  }
	  for (i = 0; i < items; i++)
	    add_history((char *)SvPV(ST(i), na));
	}

void
_rl_set_instream(fildes)
	int	fildes
	PROTOTYPE: $
	CODE:
	{
	  FILE *fd;
	  if ((fd = fdopen(fildes, "r")) == NULL)
	    warn("Gnu.xs:rl_set_instream: cannot fdopen");
	  else
	    rl_instream = fd;
	}

void
_rl_set_outstream(fildes)
	int	fildes
	PROTOTYPE: $
	CODE:
	{
	  FILE *fd;
	  if ((fd = fdopen(fildes, "w")) == NULL)
	    warn("Gnu.xs:rl_set_outstream: cannot fdopen");
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
	      xfree(matches[i]);
	    }
	    xfree((char *)matches);
	  } else {
	    /* return null list */
	  }
	}

void
_rl_store_str(pstr, id)
	const char *	pstr
	int id
	PROTOTYPE: $$
	CODE:
	{
	  size_t len;

	  ST(0) = sv_newmortal();
	  if (id < 0 || id >= sizeof(str_tbl)/sizeof(struct str_vars)) {
	    warn("Gnu.xs:_rl_store_str: Illegal `id' value: `%d'", id);
	    return;		/* return undef */
	  }

	  if (str_tbl[id].readonly) {
	    warn("Gnu.xs:_rl_store_str: store to read only variable");
	    return;
	  }

	  /* save mortal perl variable value */
	  if (str_tbl[id].buf != NULL) {
	    Safefree(str_tbl[id].buf);
	    str_tbl[id].buf = (char *)NULL;
	  }
	  len =  strlen(pstr)+1;
	  New(0, str_tbl[id].buf, len, char);
	  Copy(pstr, str_tbl[id].buf, len, char);

	  /* set C variable */
	  *(str_tbl[id].var) = str_tbl[id].buf;

	  /* return variable value */
	  sv_setpv(ST(0), str_tbl[id].buf);
	}

void
_rl_fetch_str(id)
	int id
	PROTOTYPE: $
	CODE:
	{
	  ST(0) = sv_newmortal();
	  if (id < 0 || id >= sizeof(str_tbl)/sizeof(struct str_vars)) {
	    warn("Gnu.xs:_rl_fetch_str: Illegal `id' value: `%d'", id);
	  } else {
	    sv_setpv(ST(0), *(str_tbl[id].var));
	  }
	}

void
_rl_store_int(pint, id)
	int pint
	int id
	PROTOTYPE: $$
	CODE:
	{
	  size_t len;

	  ST(0) = sv_newmortal();
	  if (id < 0 || id >= sizeof(int_tbl)/sizeof(struct int_vars)) {
	    warn("Gnu.xs:_rl_store_int: Illegal `id' value: `%d'", id);
	    return;		/* return undef */
	  }

	  /* set C variable */
	  if (int_tbl[id].charp)
	    *((char *)(int_tbl[id].var)) = (char)pint;
	  else
	    *(int_tbl[id].var) = pint;

	  /* return variable value */
	  sv_setiv(ST(0), pint);
	}

void
_rl_fetch_int(id)
	int id
	PROTOTYPE: $
	CODE:
	{
	  ST(0) = sv_newmortal();
	  if (id < 0 || id >= sizeof(int_tbl)/sizeof(struct int_vars)) {
	    warn("Gnu.xs:_rl_fetch_int: Illegal `id' value: `%d'", id);
	    /* return undef */
	  } else {
	    sv_setiv(ST(0),
		     int_tbl[id].charp ? (int)*((char *)(int_tbl[id].var))
		     : *(int_tbl[id].var));
	  }
	}
