/*
 *	Gnu.xs --- GNU Readline wrapper module
 *
 *	$Id: Gnu.xs,v 1.35 1997-01-17 17:40:13 hayashi Exp $
 *
 *	Copyright (c) 1996,1997 Hiroo Hayashi.  All rights reserved.
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
extern int rl_completion_query_items; /* should be defined in readline.h */
extern int rl_ignore_completion_duplicates; /* should be defined in readline.h */
extern int rl_line_buffer_len;

static char *dupstr (char *);	/* duplicate string */

/* from GNU Readline:xmalloc.c */
extern char *xmalloc (int);
extern char *xfree (char *);

/*
 *	custom function support routines
 */

/*
 * function name table management routines
 */
struct fnnode {			/* perl function name table entry */
  struct fnnode *next;
  char *name;
  SV *fn;
};

static struct fnnode *fnlist = NULL;

static struct fnnode *
lookup_myfun(char *name)
{
  struct fnnode *np;

  for (np = fnlist; np; np = np->next)
    if (strcmp(np->name, name) == 0)
      return np;

  return NULL;
}

static int
register_myfun(char *name, SV *fn)
{
  struct fnnode *np;

  if ((np = lookup_myfun(name)) != NULL) {
    xfree(np->name);
    np->name = dupstr(name);
    sv_setsv(np->fn, fn);
    return 0;
  } else {
    New(0, np, 1, struct fnnode);
    np->next = fnlist;
    np->name = dupstr(name);
    np->fn = newSVsv(fn);
    fnlist = np;
    return 1;
  }
}

#if 0
static int
discard_myfun(char *name)
{
  struct fnnode *np, **lp;

  for (lp = &fnlist, np = fnlist; np; lp = &(np->next), np = np->next)
    if (strcmp(np->name, name) == 0) {
      *lp = np->next;
      xfree(np->name);
      SvREFCNT_dec(np->fn);
      Safefree(np);
      return 0;
    }

  return 1;
}
#endif

/*
 * keymap name table management routines
 */
struct kmnode {			/* custom keymap table entry */
  struct kmnode *next;
  char *name;
  Keymap map;
};

static struct kmnode *kmlist = NULL;

static struct kmnode *
lookup_mykeymap(char *name)
{
  struct kmnode *np;

  for (np = kmlist; np; np = np->next)
    if (strcmp(np->name, name) == 0)
      return np;

  return NULL;
}

static int
register_mykeymap(char *name, Keymap map)
{
  struct kmnode *np;

  if ((np = lookup_mykeymap(name)) != NULL) {
    xfree(np->name);
    np->name = dupstr(name);
    np->map = map;
    return 0;
  } else {
    New(0, np, 1, struct kmnode);
    np->next = kmlist;
    np->name = dupstr(name);
    np->map = map;
    kmlist = np;
    return 1;
  }
}

static int
discard_mykeymap(char *name)
{
  struct kmnode *np, **lp;

  for (lp = &kmlist, np = kmlist; np; lp = &(np->next), np = np->next)
    if (strcmp(np->name, name) == 0) {
      *lp = np->next;
      xfree(np->name);
      Safefree(np);
      return 0;
    }

  return 1;
}

static int
my_discard_keymap(char *name)
{
  struct kmnode *np;

  if ((np = lookup_mykeymap(name)) != NULL) {
    rl_discard_keymap(np->map);
    xfree(np->name);
    Safefree(np);
    discard_mykeymap(name);
  }
}

static Keymap
my_get_keymap_by_name(char * map)
{
  rl_get_keymap_by_name(map) || lookup_mykeymap(map);
}

static char*
my_get_keymap_name(Keymap keymap)
{
  struct kmnode *np;

  /* search private map first */
  for (np = kmlist; np; np = np->next)
    if (np->map == keymap)
      return np->name;

  /* then search Readline Library map */
  return rl_get_keymap_name(keymap);
}

/*
 * function keybind table management routines
 */
struct fbnode {			/* perl function keybind table entry */
  struct fbnode *next;
  int key;
  Keymap map;
  SV *fn;
};

static struct fbnode *fblist = NULL;

static struct fbnode *
lookup_bind_myfun(int key, Keymap map)
{
  struct fbnode *np;

  for (np = fblist; np; np = np->next)
    if (np->key == key && np->map == map) {
      /*warn("lookup:[%d,%p]\n", np->key, np->fn);*/
      return np;
    }

  return NULL;
}

static int
bind_myfun(int key, SV *fn, Keymap map)
{
  struct fbnode *np;

  /*warn("register:[%d,%p]\n", key, fn);*/
  if ((np = lookup_bind_myfun(key, map)) != NULL) {
    np->key = key;
    np->map = map;
    sv_setsv(np->fn, fn);
    return 0;
  } else {
    New(0, np, 1, struct fbnode);
    np->next = fblist;
    np->key = key;
    np->map = map;
    np->fn = newSVsv(fn);
    fblist = np;
    return 1;
  }
}

static int
unbind_myfun(int key, Keymap map)
{
  struct fbnode *np, **lp;

  for (lp = &fblist, np = fblist; np; lp = &(np->next), np = np->next)
    if (np->key == key && np->map == map) {
      *lp = np->next;
      SvREFCNT_dec(np->fn);
      Safefree(np);
      return 0;
    }

  return 1;
}

static char *
rl_function_name (Function *function)
{
  register int i;

  rl_initialize_funmap ();

  for (i = 0; funmap[i]; i++)
    if (funmap[i]->function == function)
      return (funmap[i]->name);
  return NULL;
}

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

/*
 *	function pointer variable table for _rl_store_function(),
 *	_rl_fetch_funtion()
 */

static int startup_hook_wrapper(void);
static int event_hook_wrapper(void);
static int getc_function_wrapper(FILE *);
static void redisplay_function_wrapper(void);
static char *completion_entry_function_wrapper(char *, int);
static char **attempted_completion_function_wrapper(char *, int, int);

enum void_arg_func_type { STARTUP_HOOK, EVENT_HOOK, GETC_FN, REDISPLAY_FN,
			  CMP_ENT, ATMPT_COMP };

static struct fn_vars {
  Function **rlfuncp;		/* Readline Library variable */
  Function *wrapper;		/* wrapper function */
  SV *callback;			/* Perl function */
} fn_tbl[] = {
  { &rl_startup_hook,		startup_hook_wrapper,	NULL },	/* 0 */
  { &rl_event_hook,		event_hook_wrapper,	NULL },	/* 1 */
  { &rl_getc_function,		getc_function_wrapper,	NULL },	/* 2 */
  {								
    (Function **)&rl_redisplay_function,			/* 3 */
    (Function *)redisplay_function_wrapper,
    NULL
  },
  {
    (Function **)&rl_completion_entry_function,			/* 4 */
    (Function *)completion_entry_function_wrapper,		
    NULL
  },
  {
    (Function **)&rl_attempted_completion_function,		 /* 5 */
    (Function *)attempted_completion_function_wrapper,
    NULL
  }
};

/*
 * Perl function wrappers
 */
static int void_arg_func_wrapper(int);

static int
startup_hook_wrapper()		{ void_arg_func_wrapper(STARTUP_HOOK); }
static int
event_hook_wrapper()		{ void_arg_func_wrapper(EVENT_HOOK); }

/* ignore *fp. rl_getc() should be called from Perl function */
static int
getc_function_wrapper(FILE *fp)	{ void_arg_func_wrapper(GETC_FN); }
static void
redisplay_function_wrapper()	{ void_arg_func_wrapper(REDISPLAY_FN); }

static int
void_arg_func_wrapper(int type)
{
  dSP;
  int count;
  int ret;

  PUSHMARK(sp);
  count = perl_call_sv(fn_tbl[type].callback, G_SCALAR);
  SPAGAIN;

  if (count != 1)
    croak("Gnu.xs:void_arg_func_wrapper: Internal error\n");

  ret = POPi;
  PUTBACK;
  FREETMPS;
  LEAVE;
  return ret;
}

/*
 * call a perl function as rl_completion_entry_function
 */
static char *
completion_entry_function_wrapper(char *text, int state)
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

  count = perl_call_sv(fn_tbl[CMP_ENT].callback, G_SCALAR);

  SPAGAIN;

  if (count != 1)
    croak("Gnu.xs:completion_entry_function_wrapper: Internal error\n");

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
static char **
attempted_completion_function_wrapper(char *text, int start, int end)
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

  count = perl_call_sv(fn_tbl[ATMPT_COMP].callback, G_ARRAY);

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

static int
custom_function_wrapper(int count, int key)
{
  dSP;
  struct fbnode *np;

  if ((np = lookup_bind_myfun(key, rl_executing_keymap)) == NULL)
    croak("Gnu.xs:custom_function_wrapper: Internal error (lookup_bind_myfun)");

  PUSHMARK(sp);
  XPUSHs(sv_2mortal(newSViv(count)));
  XPUSHs(sv_2mortal(newSViv(key)));
  PUTBACK;

  perl_call_sv(np->fn, G_DISCARD);

  return;
}

static SV* callback_handler_callback = NULL;

static void
callback_handler_wrapper(char *line)
{
  dSP;
  int count;
  int ret;

  PUSHMARK(sp);
  XPUSHs(sv_2mortal(newSVpv(line, 0)));
  PUTBACK;

  perl_call_sv(callback_handler_callback, G_DISCARD);
}

/*
 *	Misc.
 */
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
     
#if 0
static int
rl_debug(int count, int key)
{
  warn("count:%d,key:%d\n", count, key);
  warn("rl_get_keymap():%s\n", rl_get_keymap_name(rl_get_keymap()));
  warn("rl_executing_keymap:%s\n", rl_get_keymap_name(rl_executing_keymap));
  warn("rl_binding_keymap:%s\n", rl_get_keymap_name(rl_binding_keymap));
  return 0;
}
#endif
MODULE = Term::ReadLine::Gnu		PACKAGE = Term::ReadLine::Gnu

########################################################################
#
#	Gnu Readline Library
#
########################################################################
#
#	2.1 Basic Behavior
#

# The function name "readline()" is reserved for a method name.
void
rl_readline(prompt = NULL)
	char *prompt
	PROTOTYPE: ;$
	CODE:
	{
	  char *line_read = readline(prompt);

	  ST(0) = sv_newmortal(); /* default return value is 'undef' */
	  if (line_read) {
	    sv_setpv(ST(0), line_read);
	    xfree(line_read);
	  }
	}

#
#	2.4 Readline Convenience Functions
#
#
#	2.4.1 Naming a Function
#
int
rl_add_defun(name, fn, key = -1)
	char *name
	SV *	fn
	int	key
	PROTOTYPE: $$;$
	CODE:
	{
	  if (rl_named_function(name)) {
	    warn("Gnu.xs:rl_add_defun: function name '%s' is already defined.\n",
		 name);
	    RETVAL = -1;
	    XSRETURN(1);
	  }
	  /* rl_add_defun() always returns 0. */
	  rl_add_defun(dupstr(name), custom_function_wrapper, -1);
	  /* register custom function name */
	  register_myfun(name, fn); 
	  RETVAL = 0;

	  if (key != -1) {
	    RETVAL = rl_bind_key(key, custom_function_wrapper);
	    if (RETVAL == 0)
	      bind_myfun(key, fn, rl_get_keymap());
	  }
	}
	OUTPUT:
	RETVAL

#
#	2.4.2 Selection a Keymap
#
int
rl_make_bare_keymap(name)
	char *name
	PROTOTYPE: $
	CODE:
	{
	  my_discard_keymap(name);
	  RETVAL = register_mykeymap(name, rl_make_bare_keymap());
	}
	OUTPUT:
	RETVAL
	  
int
rl_copy_keymap(map, name)
	char *map
	char *name
	PROTOTYPE: $$
	CODE:
	{
	  my_discard_keymap(name);
	  RETVAL = register_mykeymap(name, rl_copy_keymap(map));
	}
	OUTPUT:
	RETVAL	  

int
rl_make_keymap(name)
	char *name
	PROTOTYPE: $
	CODE:
	{
	  my_discard_keymap(name);
	  RETVAL = register_mykeymap(name, rl_make_keymap());
	}
	OUTPUT:
	RETVAL	  

int
rl_discard_keymap(name)
	char *name
	PROTOTYPE: $
	CODE:
	{
	  RETVAL = my_discard_keymap(name);
	}
	OUTPUT:
	RETVAL	  

void
rl_get_keymap()
	PROTOTYPE:
	CODE:
	{
	  char *keymap_name = rl_get_keymap_name(rl_get_keymap());

	  ST(0) = sv_newmortal();
	  if (keymap_name)
	    sv_setpv(ST(0), keymap_name);
	}

void
rl_set_keymap(keymap_name)
	char *keymap_name
	PROTOTYPE: $
	CODE:
	{
	  Keymap keymap = my_get_keymap_by_name(keymap_name);

	  ST(0) = sv_newmortal();
	  if (keymap_name && keymap) {
	    rl_set_keymap(keymap);
	    sv_setpv(ST(0), keymap_name);
	  }
	}

#
#	2.4.3 Binding Keys
#
int
rl_bind_key(key, function = NULL, map = NULL)
	int key
	char *function
	char *map
	PROTOTYPE: $;$$
	CODE:
	{
	  /* add code for custom function !!! */
	  Keymap keymap = map ? my_get_keymap_by_name(map) : rl_get_keymap();
	  Function *fn;
	  struct fnnode *np;

	  if ((fn = rl_named_function(function)) == NULL) {
	    warn ("Gnu.xs:rl_bind_key: undefined function `%s'\n", function);
	    RETVAL = -1;
	    XSRETURN(1);
	  }

	  RETVAL = rl_bind_key_in_map(key, fn, keymap);

	  if (RETVAL == 0 && (np = lookup_myfun(function)) != NULL)
	    bind_myfun(key, np->fn, keymap); /* perl function */
	}
	OUTPUT:
	RETVAL

int
rl_unbind_key(key, map = NULL)
	int key
	char *map
	PROTOTYPE: $;$
	CODE:
	{
	  /* add code for custom function !!! */
	  Keymap keymap = map ? my_get_keymap_by_name(map) : rl_get_keymap();

	  RETVAL = rl_unbind_key_in_map(key, keymap);
	  unbind_myfun(key, keymap); /* do nothing for C function */
	}
	OUTPUT:
	RETVAL

# add code for perl function !!!
int
rl_generic_bind(type, keyseq, data, map = NULL)
	int type
	char *keyseq
	char *data
	char *map
	PROTOTYPE: $$$;$
	CODE:
	{
	  Keymap keymap = map ? my_get_keymap_by_name(map) : rl_get_keymap();
	  void *p;

	  switch (type) {
	  case ISFUNC:
	    if (lookup_myfun(data)) {
	      warn("Gnu.xs:rl_generic_bind: does not support Perl function yet\n");
	      RETVAL = -1;
	      XSRETURN(1);
	    }
	    p = rl_named_function(data);
	    break;

	  case ISKMAP:
	    p = my_get_keymap_by_name(data);
	    break;

	  case ISMACR:
	    p = dupstr(data);	/* Who will free this memory? */
	    break;

	  defaults:
	    warn("Gnu.xs:rl_generic_bind: illegal type `%d'\n", type);
	    RETVAL = -1;
	    XSRETURN(1);
	  }

	  RETVAL = rl_generic_bind(type, keyseq, p, keymap);
	}
	OUTPUT:
	RETVAL

# add code for perl function !!!
void
rl_parse_and_bind(line)
	char *line
	PROTOTYPE: $

int
rl_read_init_file(filename = NULL)
	char *filename
	PROTOTYPE: ;$

#
#	2.4.4 Associating Function Names and Bindings
#
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
	OUTPUT:
	RETVAL

void
rl_function_of_keyseq(keyseq, map = NULL)
	char *keyseq
	char *map
	PROTOTYPE: $;$
	PPCODE:
	{
	  int type;
	  Keymap keymap = map ? my_get_keymap_by_name(map) : rl_get_keymap();
	  Function *fn = rl_function_of_keyseq(keyseq, keymap, &type);
	  char *data;

	  if (fn) {
	    switch (type) {
	    case ISFUNC:
	      data = rl_function_name(fn);
	      break;
	    case ISKMAP:
	      data = my_get_keymap_name((Keymap)fn);
	      break;
	    case ISMACR:
	      data = (char *)fn;
	      break;
	    defaults:
	      warn("Gnu.xs:rl_function_of_keyseq: illegal type `%d'\n", type);
	      XSRETURN_EMPTY;	/* return NULL list */
	    }
	    if (data) {
	      EXTEND(sp, 2);
	      PUSHs(sv_2mortal(newSVpv(data, 0)));
	      PUSHs(sv_2mortal(newSViv(type)));
	    } else
	      ;			/* return NULL list */
	  } else
	    ;			/* return NULL list */
	}
	  
void
rl_invoking_keyseqs(function, map = NULL)
	char *function
	char *map
	PROTOTYPE: $;$
	PPCODE:
	{
	  char **keyseqs;
	  Keymap keymap = map ? my_get_keymap_by_name(map) : rl_get_keymap();
	  
	  keyseqs = rl_invoking_keyseqs_in_map(rl_named_function(function),
					       keymap);

	  if (keyseqs) {
	    int i, count;

	    /* count number of entries */
	    for (count = 0; keyseqs[count]; count++)
	      ;

	    EXTEND(sp, count);
	    for (i = 0; i < count; i++) {
	      PUSHs(sv_2mortal(newSVpv(keyseqs[i], 0)));
	      xfree(keyseqs[i]);
	    }
	    xfree((char *)keyseqs);
	  } else {
	    /* return null list */
	  }
	}

void
rl_function_dumper(readable = 0)
	int	readable
	PROTOTYPE: ;$

void
rl_list_funmap_names()
	PROTOTYPE:

#
#	2.4.5 Allowing Undoing
#
int
rl_begin_undo_group()
	PROTOTYPE:

int
rl_end_undo_group()
	PROTOTYPE:

#!!! default value
void
rl_add_undo(what, start, end, text)
	int	what
	int	start
	int	end
	char	*text
	PROTOTYPE: $$$$

void
free_undo_list()
	PROTOTYPE:

int
rl_do_undo()
	PROTOTYPE:

int
rl_modifying(start = 0, end = rl_end)
	int	start
	int	end
	PROTOTYPE: ;$$

#
#	2.4.6 Redisplay
#
# in info : int rl_redisplay()
void
rl_redisplay()
	PROTOTYPE:

int
rl_forced_update_display()
	PROTOTYPE:

int
rl_on_new_line()
	PROTOTYPE:

int
rl_reset_line_state()
	PROTOTYPE:

int
_rl_message(text)
	char *text
	PROTOTYPE: $
	CODE:
	{
	  RETVAL = rl_message(text);
	}
	OUTPUT:
	RETVAL

int
rl_clear_message()
	PROTOTYPE:

#
#	2.4.7 Modifying Tex
#
int
rl_insert_text(text)
	char	*text
	PROTOTYPE: $

int
rl_delete_text(start = 0, end = rl_end)
	int	start
	int	end
	PROTOTYPE: ;$$

char *
rl_copy_text(start = 0, end = rl_end)
	int	start
	int	end
	PROTOTYPE: ;$$

int
rl_kill_text(start = 0, end = rl_end)
	int	start
	int	end
	PROTOTYPE: ;$$

#
#	2.4.8 Utility Functions
#
int
rl_read_key()
	PROTOTYPE:

int
rl_stuff_char(c)
	int	c
	PROTOTYPE: $

int
rl_initialize()
	PROTOTYPE:

int
rl_reset_terminal(terminal_name = NULL)
	char *terminal_name
	PROTOTYPE: ;$

int
ding()
	PROTOTYPE:

#
#	2.4.9 Alternate Interface
#
void
rl_callback_handler_install(prompt, lhandler)
	char * prompt
	SV * lhandler
	PROTOTYPE: $$
	CODE:
	{
	  /*
	   * Don't remove braces. The definition of SvSetSV() of
	   * Perl 5.003 has a problem.
	   */
	  if (callback_handler_callback) {
	    SvSetSV(callback_handler_callback, lhandler);
	  } else {
	    callback_handler_callback = newSVsv(lhandler);
	  }

	  rl_callback_handler_install(prompt, callback_handler_wrapper);
	}

void
rl_callback_read_char()
	PROTOTYPE:

void
rl_callback_handler_remove()
	PROTOTYPE:

#
#	2.5 Custom Completers
#

int
rl_complete_internal(what_to_do = TAB)
	int what_to_do
	PROTOTYPE: ;$

void
completion_matches(text, fn = NULL)
	char * text
	SV * fn
	PROTOTYPE: $;$
	PPCODE:
	{
	  char **matches;

	  if (SvTRUE(fn)) {
	    /* use completion_entry_function temporarily */
	    Function *rlfunc_save = *(fn_tbl[CMP_ENT].rlfuncp);
	    SV *callback_save = fn_tbl[CMP_ENT].callback;
	    fn_tbl[CMP_ENT].callback = newSVsv(fn);

	    matches = completion_matches(text,
					 completion_entry_function_wrapper);

	    SvREFCNT_dec(fn_tbl[CMP_ENT].callback);
	    fn_tbl[CMP_ENT].callback = callback_save;
	    *(fn_tbl[CMP_ENT].rlfuncp) = rlfunc_save;
	  } else
	    matches = completion_matches(text, NULL);

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

void
filename_completion_function(text, state)
	char *text
	int state
	PROTOTYPE: $$
	CODE:
	{
	  char *str = filename_completion_function(text, state);
	  ST(0) = sv_newmortal();
	  if (str) {
	    sv_setpv(ST(0), str);
	    xfree(str);
	  }
	}

void
username_completion_function(text, state)
	char *text
	int state
	PROTOTYPE: $$
	CODE:
	{
	  char *str = username_completion_function(text, state);
	  ST(0) = sv_newmortal();
	  if (str) {
	    sv_setpv(ST(0), str);
	    xfree(str);
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
	PROTOTYPE:

#
#	2.3.2 History List Management
#
void
add_history(string)
	char *string
	PROTOTYPE: $

void
remove_history(which)
	int which
	PROTOTYPE: $
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
	PROTOTYPE: $$;$
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
	PROTOTYPE:

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
	PROTOTYPE:

int
where_history()
	PROTOTYPE:

void
current_history()
	PROTOTYPE:
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
	PROTOTYPE: $
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
	PROTOTYPE:

#
#	2.3.4 Moving Around the History List
#
int
history_set_pos(pos)
	int pos
	PROTOTYPE: $

void
previous_history()
	PROTOTYPE:
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
	PROTOTYPE:
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
history_search(string, direction = -1, pos = where_history())
	char *string
	int direction
	int pos
	PROTOTYPE: $;$$
	CODE:
	{	
	  RETVAL = history_search_pos(string, direction, pos);
	}
	OUTPUT:
	RETVAL

int
history_search_prefix(string, direction = -1)
	char *string
	int direction
	PROTOTYPE: $$

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
	    XSRETURN_UNDEF;
	  }

	  if (str_tbl[id].readonly) {
	    warn("Gnu.xs:_rl_store_str: store to read only variable");
	    XSRETURN_UNDEF;
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
	    XSRETURN_UNDEF;
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

FILE *
_rl_store_iostream(stream, id)
	FILE *stream
	int id
	PROTOTYPE: $$
	CODE:
	{
	  switch (id) {
	  case 0:
	    RETVAL = rl_instream = stream;
	    break;
	  case 1:
	    RETVAL = rl_outstream = stream;
	    break;
	  default:
	    warn("Gnu.xs:_rl_store_iostream: Illegal `id' value: `%d'", id);
	    XSRETURN_UNDEF;
	    break;
	  }
	}
	OUTPUT:
	RETVAL

FILE *
_rl_fetch_iostream(id)
	int id
	PROTOTYPE: $
	CODE:
	{
	  switch (id) {
	  case 0:
	    RETVAL = rl_instream;
	    break;
	  case 1:
	    RETVAL = rl_outstream;
	    break;
	  default:
	    warn("Gnu.xs:_rl_store_iostream: Illegal `id' value: `%d'", id);
	    XSRETURN_UNDEF;
	    break;
	  }
	}
	OUTPUT:
	RETVAL

void
_rl_store_function(fn, id)
	SV *	fn
	int	id
	PROTOTYPE: $$
	CODE:
	{
	  ST(0) = sv_newmortal();
	  if (id < 0 || id >= sizeof(fn_tbl)/sizeof(struct fn_vars)) {
	    warn("Gnu.xs:_rl_store_function: Illegal `id' value: `%d'", id);
	    XSRETURN_UNDEF;
	  }
	  
	  /*
	   * Don't remove braces. The definition of SvSetSV() of
	   * Perl 5.003 has a problem.
	   */
	  if (fn_tbl[id].callback) {
	    SvSetSV(fn_tbl[id].callback, fn);
	  } else {
	    fn_tbl[id].callback = newSVsv(fn);
	  }

	  *(fn_tbl[id].rlfuncp) = SvTRUE(fn) ? fn_tbl[id].wrapper : NULL;

	  /* return variable value */
	  sv_setsv(ST(0), fn);
	}

void
_rl_fetch_function(id)
	int	id
	PROTOTYPE: $
	CODE:
	{
	  ST(0) = sv_newmortal();
	  if (id < 0 || id >= sizeof(fn_tbl)/sizeof(struct fn_vars)) {
	    warn("Gnu.xs:_rl_fetch_function: Illegal `id' value: `%d'", id);
	    /* return undef */
	  } else {
	    if (fn_tbl[id].callback)
	      sv_setsv(ST(0), fn_tbl[id].callback);
	  }
	}
