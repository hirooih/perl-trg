/*
 *	Gnu.xs --- GNU Readline wrapper module
 *
 *	$Id: Gnu.xs,v 1.20 1996-12-31 13:58:03 hayashi Exp $
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

extern char *rl_prompt;		/* should be defined in readline.h */
/*
 *	string variable table for _rl_store_str(), _rl_fetch_str()
 */
static struct str_vars {
  char **var;
  int accessed;
  int readonly;
} str_tbl[] = {
  /* When you change length of rl_line_buffer, change
     rl_line_buffer_len also. */
  &rl_line_buffer,				0, 0,	/* 0 */
  &rl_prompt,					0, 1,	/* 1 */
  &rl_library_version,				0, 1,	/* 2 */
  &rl_terminal_name,				0, 0,	/* 3 */
  &rl_readline_name,				0, 0,	/* 4 */
  
  &rl_basic_word_break_characters,		0, 0,	/* 5 */
  &rl_basic_quote_characters,			0, 0,	/* 6 */
  &rl_completer_word_break_characters,		0, 0,	/* 7 */
  &rl_completer_quote_characters,		0, 0,	/* 8 */
  &rl_filename_quote_characters,		0, 0,	/* 9 */
  &rl_special_prefixes,				0, 0,	/* 10 */
  
  &history_no_expand_chars,			0, 0,	/* 11 */
  &history_search_delimiter_chars,		0, 0	/* 12 */
};

/*
 *	integer variable table for _rl_store_int(), _rl_fetch_int()
 */

extern int rl_completion_query_items; /* should be defined in readline.h */
extern int rl_ignore_completion_duplicates; /* should be defined in readline.h */
extern int rl_line_buffer_len;

static struct int_vars {
  int *var;
  int charp;
} int_tbl[] = {
  &rl_line_buffer_len,				0,	/* 0 */
  &rl_point,					0,	/* 1 */
  &rl_end,					0,	/* 2 */
  &rl_mark,					0,	/* 3 */
  &rl_done,					0,	/* 4 */
  &rl_pending_input,				0,	/* 5 */

  &rl_completion_query_items,			0,	/* 6 */
  &rl_completion_append_character,		0,	/* 7 : int */
  &rl_ignore_completion_duplicates,		0,	/* 8 */
  &rl_filename_completion_desired,		0,	/* 9 */
  &rl_filename_quoting_desired,			0,	/* 10 */
  &rl_inhibit_completion,			0,	/* 11 */

  &history_base,				0,	/* 12 */
  &history_length,				0,	/* 13 */
  (int *)&history_expansion_char,		1,	/* 14 */
  (int *)&history_subst_char,			1,	/* 15 */
  (int *)&history_comment_char,			1,	/* 16 */
  &history_quotes_inhibit_expansion,		0	/* 17 */
};

/* from GNU Readline:xmalloc.c */
extern char *xmalloc (int);
extern char *xfree (char *);

static char *
dupstr (s)			/* duplicate string */
     char *s;
{
  char *r;
     
/* Use xmalloc(), because 'r' will be freed in GNU Readline Library routine */
  r = xmalloc (strlen (s) + 1);	
  strcpy (r, s);
  return (r);
}
     
static char *preput_str = NULL;
static int
rl_insert_preput ()
{
  if (preput_str)
    rl_insert_text(preput_str);
  return 0;
}

/*
 *	custom function support routines
 */
struct fnode {			/* table entry */
  struct fnode *next;
  int key;
  SV *fn;
};

static struct fnode *flist = NULL;

struct fnode *
lookup_defun(int key)
{
  struct fnode *np;

  for (np = flist; np; np = np->next)
    if (np->key == key) {
      /*warn("lookup:[%d,%p]\n", np->key, np->fn);*/
      return np;
    }

  return NULL;
}

static int
register_defun(int key, SV *fn)
{
  struct fnode *np;

  /*warn("register:[%d,%p]\n", key, fn);*/
  if ((np = lookup_defun(key)) != NULL) {
    np->key = key;
    np->fn = newSVsv(fn);
    return 0;
  } else {
    New(0, np, 1, struct fnode);
    np->next = flist;
    np->key = key;
    np->fn = newSVsv(fn);
    flist = np;
    return 1;
  }
}

static int
dismiss_defun(int key)
{
  struct fnode *np, **lp;

  for (lp = &flist, np = flist; np; lp = &(np->next), np = np->next)
    if (np->key == key) {
      *lp = np->next;
      SvREFCNT_dec(np->fn);
      Safefree(np);
      return 0;
    }

  return 1;
}

static int
custom_function_lapper(int count, int key)
{
  dSP;
  struct fnode *np;

  if ((np = lookup_defun(key)) == NULL)
    croak("Gnu.xs:custom_function_lapper: Internal error (lookup_defun)");

  PUSHMARK(sp);
  XPUSHs(sv_2mortal(newSViv(count)));
  XPUSHs(sv_2mortal(newSViv(key)));
  PUTBACK;

  /*warn("lapper:[%d,%p]\n", key, np-fn);*/
  perl_call_sv(np->fn, G_DISCARD);
  /*warn("[return from perl_call_sv]\n");*/

  return;
}

/*
 * call a perl function as rl_completion_entry_function
 */
static SV * completion_entry_function = NULL;

static char *
completion_entry_function_lapper(char *text, int state)
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
    croak("Gnu.xs:completion_entry_function_lapper: Internal error\n");

  match = POPs;
  str = SvOK(match) ? dupstr(SvPV(match, na)) : NULL;

  PUTBACK;
  FREETMPS;
  LEAVE;
  return str;
}

/*
 * call a perl function as rl_attempted_completion_function
 */
static SV * attempted_completion_function = NULL;

static char **
attempted_completion_function_lapper(char *text, int start, int end)
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

  matches = NULL;

  if (count > 1) {
    int i;

    matches = (char **)xmalloc (sizeof(char *) * (count + 1));
    matches[count] = NULL;
    for (i = count - 1; i >= 0; i--)
      matches[i] = dupstr(POPp);

  } else if (count == 1) {	/* return NULL if undef is returned */
    SV *v = POPs;

    if (SvOK(v)) {
      matches = (char **)xmalloc (sizeof(char *) * 2);
      matches[0] = dupstr(SvPV(v, na));
      matches[1] = NULL;
    }
  }

  PUTBACK;
  FREETMPS;
  LEAVE;

  return matches;
}

MODULE = Term::ReadLine::Gnu		PACKAGE = Term::ReadLine::Gnu

########################################################################
#
#	Gnu Readline Library
#
########################################################################
#
#	2.1 Basic Behavior
#
void
_rl_readline(prompt = NULL, preput = NULL)
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

	  ST(0) = sv_newmortal(); /* default return value is 'undef' */
	  if (line_read) {
	    sv_setpv(ST(0), line_read);
	    xfree(line_read);
	  }
	}

#
#	2.4 Readline Convenience Functions
#
#	2.4.1 Naming a Function
int
rl_add_defun(fn, key, name = "")
	SV *	fn
	int	key
	char *name
	PROTOTYPE: $$;$
	CODE:
	{
	  /*warn("add_defun:[%d,%p]\n", key, fn);*/
	  register_defun(key, fn);

	  if (name[0] == '\0')
	    RETVAL = rl_bind_key(custom_function_lapper, key);
	  else
	    RETVAL = rl_add_defun(name, custom_function_lapper, key);

	  if (RETVAL)
	    dismiss_defun(key);
	}

#	2.4.2 Selection a Keymap

#	2.4.3 Binding Keys
int
rl_unbind_key(key)
	int	key
	PROTOTYPE: $
	CODE:
	{
	  dismiss_defun(key);	/* do nothing if key is bind to C function */
	  rl_unbind_key(key);
	}

void
rl_parse_and_bind(line)
	char *line
	PROTOTYPE: $

int
rl_read_init_file(filename = NULL)
	char *filename
	PROTOTYPE: ;$

#	2.4.4 Associating Function Names and Bindings
int
rl_do_named_function(name, count = 1, key = -1)
	char	*name
	int	count
	int	key
	PROTOTYPE: $;$$
	CODE:
	{
	  Function *fn;
	  if ((fn = rl_named_function(name)) != NULL) {
	    RETVAL = (*fn)(count, key);
	  } else {
	    warn("Gnu.xs:_rl_do_named_function: undefined function `%s'",
		 name);
	    RETVAL = -1;
	  }
	}

void
rl_function_dumper(readable)
	int	readable

void
rl_list_funmap_names()

#	2.4.5 Allowing Undoing
int
rl_begin_undo_group()

int
rl_end_undo_group()

void
rl_add_undo(what, start, end, text)
	int	what
	int	start
	int	end
	char	*text

void
free_undo_list()

int
rl_do_undo()

int
rl_modifying(start, end)
	int	start
	int	end

#	2.4.6 Redisplay
# in info : int rl_redisplay()
void
rl_redisplay()

int
rl_forced_update_display()

int
rl_on_new_line()

int
rl_reset_line_state()

int
rl_message(text)
	char *text

int
rl_clear_message()

#	2.4.7 Modifying Tex
int
rl_insert_text(text)
	char	*text

int
rl_delete_text(start, end)
	int	start
	int	end

char *
rl_copy_text(start, end)
	int	start
	int	end

int
rl_kill_text(start, end)
	int	start
	int	end

#	2.4.8 Utility Functions
int
rl_read_key()

int
rl_stuff_char(c)
	int	c

int
rl_initialize()

int
rl_reset_terminal(terminal_name)
	char *terminal_name

int
ding()

#
#	2.5 Custom Completers
#
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
	    /*
	     * Don't remove braces. The definition of SvSetSV() of
	     * Perl 5.003 has a problem.
	     */
	    if (completion_entry_function) {
	      SvSetSV(completion_entry_function, fn);
	    } else {
	      completion_entry_function = newSVsv(fn);
	    }

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
	    rl_attempted_completion_function = NULL;
	  } else {
	    /* Don't remove braces. */
	    if (attempted_completion_function) {
	      SvSetSV(attempted_completion_function, fn);
	    } else {
	      attempted_completion_function = newSVsv(fn);
	    }

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
	    if (save)
	      SvSetSV(completion_entry_function, fn);
	    else
	      completion_entry_function = newSVsv(fn);
	    matches = completion_matches(text,
					 completion_entry_function_lapper);
	    completion_entry_function = save;
	  }
	  if (matches) {
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

########################################################################
#
#	Gnu History Library
#
########################################################################
#
#	2.3.1 Initializing History and State Management
#
void
using_history()

#
#	2.3.2 History List Management
#
void
add_history(...)
	PROTOTYPE: @
	CODE:
	{
	  register int i;
	  for (i = 0; i < items; i++)
	    add_history((char *)SvPV(ST(i), na));
	}

void
remove_history(which)
	int which
	CODE:
	{
	  HIST_ENTRY *entry;
	  entry = remove_history(which);
	  ST(0) = sv_newmortal();
	  if (entry && entry->line)
	    sv_setpv(ST(0), entry->line);
	  xfree(entry->line);
	  xfree(entry->data);
	  xfree((char *)entry);
	}

void
replace_history_entry(which, line, data = NULL)
	int which
	char *line
	char *data
	CODE:
	{
	  HIST_ENTRY *entry;
	  entry = replace_history_entry(which, line, data);
	  ST(0) = sv_newmortal();
	  if (entry && entry->line)
	    sv_setpv(ST(0), entry->line);
	  xfree(entry->line);
	  xfree(entry->data);
	  xfree((char *)entry);
	}

void
clear_history()

int
stifle_history(i)
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

int
history_is_stifled()

void
_rl_SetHistory(...)
	PROTOTYPE: @
	CODE:
	{
	  register int i;

	  clear_history();
	  for (i = 0; i < items; i++)
	    add_history((char *)SvPV(ST(i), na));
	}

#
#	2.3.3 Information About the History List
#
int
where_history()

void
current_history()
	CODE:
	{
	  HIST_ENTRY *entry;
	  entry = current_history();
	  ST(0) = sv_newmortal();
	  if (entry && entry->line)
	    sv_setpv(ST(0), entry->line);
	}

void
history_get(offset)
	int offset
	CODE:
	{
	  HIST_ENTRY *hist;

	  ST(0) = sv_newmortal(); /* default return value is 'undef' */

	  hist = history_get(offset);
	  if (hist && hist->line)
	    sv_setpv(ST(0), hist->line);
	}

int
history_total_bytes()

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

#
#	2.3.4 Moving Around the History List
#
int
history_set_pos(pos)
	int pos

void
previous_history()
	CODE:
	{
	  HIST_ENTRY *entry;
	  entry = previous_history();
	  ST(0) = sv_newmortal();
	  if (entry && entry->line)
	    sv_setpv(ST(0), entry->line);
	}

void
next_history()
	CODE:
	{
	  HIST_ENTRY *entry;
	  entry = next_history();
	  ST(0) = sv_newmortal();
	  if (entry && entry->line)
	    sv_setpv(ST(0), entry->line);
	}

#
#	2.3.5 Searching the History List
#
int
history_search(string, direction)
	char *string
	int direction

int
history_search_prefix(string, direction)
	char *string
	int direction

int
history_search_pos(string, direction, pos)
	char *string
	int direction
	int pos

#
#	2.3.6 Managing the History File
#
int
read_history_range(filename = NULL, from = 0, to = -1)
	char *filename
	int from
	int to
	PROTOTYPE: ;$$$

int
write_history(filename = NULL)
	char *filename
	PROTOTYPE: ;$

int
append_history(nelements, filename = NULL)
	int nelements
	char *filename
	PROTOTYPE: ;$

int
history_truncate_file(filename = NULL, nlines = 0)
	char *filename
	int nlines
	PROTOTYPE: ;$$

#
#	2.3.7 History Expansion
#
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

#
#	Readline/History Library Variable Access Routines
#

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

#	  warn("\n[%d;%d;var:%p,%p]\n", id, str_tbl[id].accessed,
#	       *str_tbl[id].var, str_tbl[id].var);
	  /*
	   * Use xmalloc() instead of New(),
	   * because this block may be reallocated by readline library.
	   */
	  if (str_tbl[id].accessed && *str_tbl[id].var) {
	    xfree(*str_tbl[id].var); /* don't free static area */
	    *str_tbl[id].var = NULL;
	  }
	  str_tbl[id].accessed = 1;

	  len = strlen(pstr)+1;
	  *str_tbl[id].var = xmalloc(len);
	  Copy(pstr, *str_tbl[id].var, len, char);

#	  warn("[%d;%d;var:%p,%p]\n", id, str_tbl[id].accessed,
#	       *str_tbl[id].var, str_tbl[id].var);

	  /* return variable value */
	  sv_setpv(ST(0), *str_tbl[id].var);
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

void
_rl_set_instream(fildes)
	int	fildes
	PROTOTYPE: $
	CODE:
	{
	  FILE *fd;
	  if ((fd = fdopen(fildes, "r")) != NULL)
	    rl_instream = fd;
	  else
	    warn("Gnu.xs:rl_set_instream: cannot fdopen");
	}

void
_rl_set_outstream(fildes)
	int	fildes
	PROTOTYPE: $
	CODE:
	{
	  FILE *fd;
	  if ((fd = fdopen(fildes, "w")) != NULL)
	    rl_outstream = fd;
	  else
	    warn("Gnu.xs:rl_set_outstream: cannot fdopen");
	}
