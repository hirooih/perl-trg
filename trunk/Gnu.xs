/*
 *	Gnu.xs --- GNU Readline wrapper module
 *
 *	$Id: Gnu.xs,v 1.52 1997-03-16 17:20:21 hayashi Exp $
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

/* following variables should be defined in readline.h */
extern char *rl_prompt;
extern int rl_completion_query_items;
extern int rl_ignore_completion_duplicates;

#ifdef __STDC__
/* from GNU Readline:xmalloc.c */
extern char *xmalloc (int);
extern char *xfree (char *);
void rl_extend_line_buffer (int);
#else
extern char *xmalloc ();
extern char *xfree ();
void rl_extend_line_buffer ();
#endif /* __STDC__ */

static char *
dupstr(s)			/* duplicate string */
     char *s;
{
  /*
   * Use xmalloc(), because allocated block will be freed in GNU
   * Readline Library routine.
   * Don't make a macro, because the variable 's' is evaluated twice.
   */
  int len = strlen(s) + 1;
  char *d = xmalloc(len);
  Copy(s, d, len, char);	/* Is Copy() better than strcpy() in XS? */
  return d;
}

/*
 * should be defined readline/bind.c ?
 */
static char *
rl_get_function_name (function)
     Function *function;
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
  /* When you change length of rl_line_buffer, you must call
     rl_extend_line_buffer().  See _rl_store_rl_line_buffer() */
  { &rl_line_buffer,				0, 0 },	/* 0 */
  { &rl_prompt,					0, 1 },	/* 1 */
  { &rl_library_version,			0, 1 },	/* 2 */
  { &rl_terminal_name,				0, 0 },	/* 3 */
  { &rl_readline_name,				0, 0 },	/* 4 */
  
  { &rl_basic_word_break_characters,		0, 0 },	/* 5 */
  { &rl_basic_quote_characters,			0, 0 },	/* 6 */
  { &rl_completer_word_break_characters,	0, 0 },	/* 7 */
  { &rl_completer_quote_characters,		0, 0 },	/* 8 */
  { &rl_filename_quote_characters,		0, 0 },	/* 9 */
  { &rl_special_prefixes,			0, 0 },	/* 10 */
  
  { &history_no_expand_chars,			0, 0 },	/* 11 */
  { &history_search_delimiter_chars,		0, 0 }	/* 12 */
};

/*
 *	integer variable table for _rl_store_int(), _rl_fetch_int()
 */

static struct int_vars {
  int *var;
  int charp;
} int_tbl[] = {
  { &rl_point,					0 },	/* 0 */
  { &rl_end,					0 },	/* 1 */
  { &rl_mark,					0 },	/* 2 */
  { &rl_done,					0 },	/* 3 */
  { &rl_pending_input,				0 },	/* 4 */

  { &rl_completion_query_items,			0 },	/* 5 */
  { &rl_completion_append_character,		0 },	/* 6 */
  { &rl_ignore_completion_duplicates,		0 },	/* 7 */
  { &rl_filename_completion_desired,		0 },	/* 8 */
  { &rl_filename_quoting_desired,		0 },	/* 9 */
  { &rl_inhibit_completion,			0 },	/* 10 */

  { &history_base,				0 },	/* 11 */
  { &history_length,				0 },	/* 12 */
  { (int *)&history_expansion_char,		1 },	/* 13 */
  { (int *)&history_subst_char,			1 },	/* 14 */
  { (int *)&history_comment_char,		1 },	/* 15 */
  { &history_quotes_inhibit_expansion,		0 }	/* 16 */
};

/*
 *	function pointer variable table for _rl_store_function(),
 *	_rl_fetch_funtion()
 */

#ifdef __STDC__
static int startup_hook_wrapper(void);
static int event_hook_wrapper(void);
static int getc_function_wrapper(FILE *);
static void redisplay_function_wrapper(void);
static char *completion_entry_function_wrapper(char *, int);
static char **attempted_completion_function_wrapper(char *, int, int);
#else
static int startup_hook_wrapper();
static int event_hook_wrapper();
static int getc_function_wrapper();
static void redisplay_function_wrapper();
static char *completion_entry_function_wrapper();
static char **attempted_completion_function_wrapper();
#endif /* __STDC__ */

enum void_arg_func_type { STARTUP_HOOK, EVENT_HOOK, GETC_FN, REDISPLAY_FN,
			  CMP_ENT, ATMPT_COMP };

static struct fn_vars {
  Function **rlfuncp;		/* Readline Library variable */
  Function *defaultfn;		/* default function */
  Function *wrapper;		/* wrapper function */
  SV *callback;			/* Perl function */
} fn_tbl[] = {
  { &rl_startup_hook,	NULL,	startup_hook_wrapper,	NULL },	/* 0 */
  { &rl_event_hook,	NULL,	event_hook_wrapper,	NULL },	/* 1 */
  { &rl_getc_function,	rl_getc, getc_function_wrapper,	NULL },	/* 2 */
  {								
    (Function **)&rl_redisplay_function,			/* 3 */
    (Function *)rl_redisplay,
    (Function *)redisplay_function_wrapper,
    NULL
  },
  {
    (Function **)&rl_completion_entry_function,			/* 4 */
    NULL,
    (Function *)completion_entry_function_wrapper,		
    NULL
  },
  {
    (Function **)&rl_attempted_completion_function,		 /* 5 */
    NULL,
    (Function *)attempted_completion_function_wrapper,
    NULL
  }
};

/*
 * Perl function wrappers
 */

#ifdef __STDC__
static int void_arg_func_wrapper(int);
#else
static int void_arg_func_wrapper();
#endif

static int
startup_hook_wrapper()		{ return void_arg_func_wrapper(STARTUP_HOOK); }
static int
event_hook_wrapper()		{ return void_arg_func_wrapper(EVENT_HOOK); }

static int
getc_function_wrapper(fp)
     FILE *fp;
{
  /*
   * 'FILE *fp' is ignored.  Use rl_instream instead in the getc_function.
   * How can I pass 'FILE *fp'?
   */
  return void_arg_func_wrapper(GETC_FN);
}

static void
redisplay_function_wrapper()	{ void_arg_func_wrapper(REDISPLAY_FN); }

static int
void_arg_func_wrapper(type)
     int type;
{
  dSP;
  int count;
  int ret;

  ENTER;
  SAVETMPS;

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
completion_entry_function_wrapper(text, state)
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
  if (text) {
    XPUSHs(sv_2mortal(newSVpv(text, 0)));
  } else {
    XPUSHs(&sv_undef);
  }
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
attempted_completion_function_wrapper(text, start, end)
     char *text;
     int start;
     int end;
{
  dSP;
  int count;
  char **matches;
  
  ENTER;
  SAVETMPS;

  PUSHMARK(sp);
  if (text) {
    XPUSHs(sv_2mortal(newSVpv(text, 0)));
  } else {
    XPUSHs(&sv_undef);
  }
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

/*
 *	If you need more custom functions, define more funntion_wrapper_xx()
 *	and add entry on fntbl[].
 */

#ifdef __STDC__
static int function_wrapper(int count, int key, int id);
static int
function_wrapper_00(int c, int k) { return function_wrapper(c, k,  0); }
static int
function_wrapper_01(int c, int k) { return function_wrapper(c, k,  1); }
static int
function_wrapper_02(int c, int k) { return function_wrapper(c, k,  2); }
static int
function_wrapper_03(int c, int k) { return function_wrapper(c, k,  3); }
static int
function_wrapper_04(int c, int k) { return function_wrapper(c, k,  4); }
static int
function_wrapper_05(int c, int k) { return function_wrapper(c, k,  5); }
static int
function_wrapper_06(int c, int k) { return function_wrapper(c, k,  6); }
static int
function_wrapper_07(int c, int k) { return function_wrapper(c, k,  7); }
static int
function_wrapper_08(int c, int k) { return function_wrapper(c, k,  8); }
static int
function_wrapper_09(int c, int k) { return function_wrapper(c, k,  9); }
static int
function_wrapper_10(int c, int k) { return function_wrapper(c, k, 10); }
static int
function_wrapper_11(int c, int k) { return function_wrapper(c, k, 11); }
static int
function_wrapper_12(int c, int k) { return function_wrapper(c, k, 12); }
static int
function_wrapper_13(int c, int k) { return function_wrapper(c, k, 13); }
static int
function_wrapper_14(int c, int k) { return function_wrapper(c, k, 14); }
static int
function_wrapper_15(int c, int k) { return function_wrapper(c, k, 15); }
#else
static int function_wrapper();
static int
function_wrapper_00(c, k) int c; int k; { return function_wrapper(c, k,  0); }
static int
function_wrapper_01(c, k) int c; int k; { return function_wrapper(c, k,  1); }
static int
function_wrapper_02(c, k) int c; int k; { return function_wrapper(c, k,  2); }
static int
function_wrapper_03(c, k) int c; int k; { return function_wrapper(c, k,  3); }
static int
function_wrapper_04(c, k) int c; int k; { return function_wrapper(c, k,  4); }
static int
function_wrapper_05(c, k) int c; int k; { return function_wrapper(c, k,  5); }
static int
function_wrapper_06(c, k) int c; int k; { return function_wrapper(c, k,  6); }
static int
function_wrapper_07(c, k) int c; int k; { return function_wrapper(c, k,  7); }
static int
function_wrapper_08(c, k) int c; int k; { return function_wrapper(c, k,  8); }
static int
function_wrapper_09(c, k) int c; int k; { return function_wrapper(c, k,  9); }
static int
function_wrapper_10(c, k) int c; int k; { return function_wrapper(c, k, 10); }
static int
function_wrapper_11(c, k) int c; int k; { return function_wrapper(c, k, 11); }
static int
function_wrapper_12(c, k) int c; int k; { return function_wrapper(c, k, 12); }
static int
function_wrapper_13(c, k) int c; int k; { return function_wrapper(c, k, 13); }
static int
function_wrapper_14(c, k) int c; int k; { return function_wrapper(c, k, 14); }
static int
function_wrapper_15(c, k) int c; int k; { return function_wrapper(c, k, 15); }
#endif /* __STDC__ */

static struct fnnode {
  Function *wrapper;		/* C wrapper function */
  SV *pfn;			/* Perl function */
} fntbl[] = {
  { function_wrapper_00,	NULL },
  { function_wrapper_01,	NULL },
  { function_wrapper_02,	NULL },
  { function_wrapper_03,	NULL },
  { function_wrapper_04,	NULL },
  { function_wrapper_05,	NULL },
  { function_wrapper_06,	NULL },
  { function_wrapper_07,	NULL },
  { function_wrapper_08,	NULL },
  { function_wrapper_09,	NULL },
  { function_wrapper_10,	NULL },
  { function_wrapper_11,	NULL },
  { function_wrapper_12,	NULL },
  { function_wrapper_13,	NULL },
  { function_wrapper_14,	NULL },
  { function_wrapper_15,	NULL }
};

static int
function_wrapper(count, key, id)
     int count;
     int key;
     int id;
{
  dSP;

  PUSHMARK(sp);
  XPUSHs(sv_2mortal(newSViv(count)));
  XPUSHs(sv_2mortal(newSViv(key)));
  PUTBACK;

  perl_call_sv(fntbl[id].pfn, G_DISCARD);

  return 0;
}

static SV* callback_handler_callback = NULL;

static void
callback_handler_wrapper(line)
     char *line;
{
  dSP;

  PUSHMARK(sp);
  if (line) {
    XPUSHs(sv_2mortal(newSVpv(line, 0)));
  } else {
    XPUSHs(&sv_undef);
  }
  PUTBACK;

  perl_call_sv(callback_handler_callback, G_DISCARD);
}

/*
 * make separate name space for low level XS functions and there methods
 */

MODULE = Term::ReadLine::Gnu		PACKAGE = Term::ReadLine::Gnu::XS

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
Function *
rl_add_defun(name, fn, key = -1)
	char *name
	SV *fn
	int key
	PROTOTYPE: $$;$
	CODE:
	{
	  int i;
	  int nentry = sizeof(fntbl)/sizeof(struct fnnode);

	  /* search an empty slot */
	  for (i = 0; i < nentry; i++)
	    if (! fntbl[i].pfn)
	      break;
	  
	  if (i >= nentry) {
	    warn("Gnu.xs:rl_add_defun: custom function table is full. The maximum number of custum function is %d.\n",
		 nentry);
	    XSRETURN_UNDEF;
	  }

	  fntbl[i].pfn = newSVsv(fn);
	  
	  /* rl_add_defun() always returns 0. */
	  rl_add_defun(dupstr(name), fntbl[i].wrapper, key);
	  RETVAL = fntbl[i].wrapper;
	}
	OUTPUT:
	RETVAL

#
#	2.4.2 Selection a Keymap
#
Keymap
rl_make_bare_keymap()
	PROTOTYPE:
	  
Keymap
_rl_copy_keymap(map)
	Keymap map
	PROTOTYPE: $
	CODE:
	{
	  RETVAL = rl_copy_keymap(map);
	}
	OUTPUT:
	RETVAL

Keymap
rl_make_keymap()
	PROTOTYPE:

Keymap
_rl_discard_keymap(map)
	Keymap map
	PROTOTYPE: $
	CODE:
	{
	  rl_discard_keymap(map);
	  RETVAL = map;
	}
	OUTPUT:
	RETVAL

Keymap
rl_get_keymap()
	PROTOTYPE:

Keymap
_rl_set_keymap(map)
	Keymap map
	PROTOTYPE: $
	CODE:
	{
	  rl_set_keymap(map);
	  RETVAL = map;
	}
	OUTPUT:
	RETVAL

Keymap
rl_get_keymap_by_name(name)
	char *name
	PROTOTYPE: $

char *
rl_get_keymap_name(map)
	Keymap map
	PROTOTYPE: $

#
#	2.4.3 Binding Keys
#
int
_rl_bind_key(key, function, map = rl_get_keymap())
	int key
	Function *function
	Keymap map
	PROTOTYPE: $$;$
	CODE:
	{
	  RETVAL = rl_bind_key_in_map(key, function, map);
	}
	OUTPUT:
	RETVAL

int
_rl_unbind_key(key, map = rl_get_keymap())
	int key
	Keymap map
	PROTOTYPE: $;$
	CODE:
	{
	  RETVAL = rl_unbind_key_in_map(key, map);
	}
	OUTPUT:
	RETVAL

int
_rl_generic_bind_function(keyseq, function, map = rl_get_keymap())
	char *keyseq
	Function *function
	Keymap map
	PROTOTYPE: $$;$
	CODE:
	{
	  RETVAL = rl_generic_bind(ISFUNC, keyseq, (char *)function, map);
	}
	OUTPUT:
	RETVAL

int
_rl_generic_bind_keymap(keyseq, keymap, map = rl_get_keymap())
	char *keyseq
	Keymap keymap
	Keymap map
	PROTOTYPE: $$;$
	CODE:
	{
	  RETVAL = rl_generic_bind(ISKMAP, keyseq, (char *)keymap, map);
	}
	OUTPUT:
	RETVAL

int
_rl_generic_bind_macro(keyseq, macro, map = rl_get_keymap())
	char *keyseq
	char *macro
	Keymap map
	PROTOTYPE: $$;$
	CODE:
	{
	  RETVAL = rl_generic_bind(ISMACR, keyseq, macro, map);
	}
	OUTPUT:
	RETVAL

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
_rl_call_function(function, count = 1, key = -1)
	Function *function
	int count
	int key
	PROTOTYPE: $;$$
	CODE:
	{
	  RETVAL = (*function)(count, key);
	}
	OUTPUT:
	RETVAL

Function *
rl_named_function(name)
	char *name
	PROTOTYPE: $

char *
rl_get_function_name(function)
	Function *function
	PROTOTYPE: $

void
rl_function_of_keyseq(keyseq, map = rl_get_keymap())
	char *keyseq
	Keymap map
	PROTOTYPE: $;$
	PPCODE:
	{
	  int type;
	  Function *p = rl_function_of_keyseq(keyseq, map, &type);
	  SV *sv;

	  if (p) {
	    sv = sv_newmortal();
	    switch (type) {
	    case ISFUNC:
	      sv_setref_pv(sv, "FunctionPtr", (void*)p);
	      break;
	    case ISKMAP:
	      sv_setref_pv(sv, "Keymap", (void*)p);
	      break;
	    case ISMACR:
	      sv_setpv(sv, (char *)p);
	      break;
	    default:
	      warn("Gnu.xs:rl_function_of_keyseq: illegal type `%d'\n", type);
	      XSRETURN_EMPTY;	/* return NULL list */
	    }
	    EXTEND(sp, 2);
	    PUSHs(sv);
	    PUSHs(sv_2mortal(newSViv(type)));
	  } else
	    ;			/* return NULL list */
	}
	  
void
_rl_invoking_keyseqs(function, map = rl_get_keymap())
	Function *function
	Keymap map
	PROTOTYPE: $;$
	PPCODE:
	{
	  char **keyseqs;
	  
	  keyseqs = rl_invoking_keyseqs_in_map(function, map);

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
	int readable
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

void
rl_add_undo(what, start, end, text)
	int what
	int start
	int end
	char *text
	PROTOTYPE: $$$$
	CODE:
	{
	  rl_add_undo(what, start, end, dupstr(text));
	}

void
free_undo_list()
	PROTOTYPE:

int
rl_do_undo()
	PROTOTYPE:

int
rl_modifying(start = 0, end = rl_end)
	int start
	int end
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
#	2.4.7 Modifying Text
#
int
rl_insert_text(text)
	char *text
	PROTOTYPE: $

int
rl_delete_text(start = 0, end = rl_end)
	int start
	int end
	PROTOTYPE: ;$$

char *
rl_copy_text(start = 0, end = rl_end)
	int start
	int end
	PROTOTYPE: ;$$

int
rl_kill_text(start = 0, end = rl_end)
	int start
	int end
	PROTOTYPE: ;$$

#
#	2.4.8 Utility Functions
#
int
rl_read_key()
	PROTOTYPE:

int
rl_getc(stream)
	FILE *stream
	PROTOTYPE: $

int
rl_stuff_char(c)
	int c
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
	char *prompt
	SV *lhandler
	PROTOTYPE: $$
	CODE:
	{
	  static char *cb_prompt = NULL;
	  int len = strlen(prompt) + 1;

	  /* The value of prompt may be used after return from this routine. */
	  if (cb_prompt)
	    Safefree(cb_prompt);
	  New(0, cb_prompt, len, char);
	  Copy(prompt, cb_prompt, len, char);

	  /*
	   * Don't remove braces. The definition of SvSetSV() of
	   * Perl 5.003 has a problem.
	   */
	  if (callback_handler_callback) {
	    SvSetSV(callback_handler_callback, lhandler);
	  } else {
	    callback_handler_callback = newSVsv(lhandler);
	  }

	  rl_callback_handler_install(cb_prompt, callback_handler_wrapper);
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
	char *text
	SV *fn
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
replace_history_entry(which, line)
	int which
	char *line
	PROTOTYPE: $$
	CODE:
	{
	  HIST_ENTRY *entry;
	  entry = replace_history_entry(which, line, (char *)NULL);
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
	  HIST_ENTRY *entry;
	  entry = history_get(offset);
	  ST(0) = sv_newmortal();
	  if (entry && entry->line)
	    sv_setpv(ST(0), entry->line);
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
	PROTOTYPE: $;$

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
	const char *pstr
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

	  /*
	   * Use xmalloc() and xfree() instead of New() and Safefree(),
	   * because this block may be reallocated by the Readline Library.
	   */
	  if (str_tbl[id].accessed && *str_tbl[id].var) {
	    /*
	     * First time a variable is used by this routine,
	     * it may be a static area.  So it cannot be freed.
	     */
	    xfree(*str_tbl[id].var);
	    *str_tbl[id].var = NULL;
	  }
	  str_tbl[id].accessed = 1;

	  len = strlen(pstr) + 1;
	  *str_tbl[id].var = xmalloc(len);
	  Copy(pstr, *str_tbl[id].var, len, char);

	  /* return variable value */
	  sv_setpv(ST(0), *str_tbl[id].var);
	}

void
_rl_store_rl_line_buffer(pstr)
	const char *pstr
	PROTOTYPE: $
	CODE:
	{
	  size_t len;

	  ST(0) = sv_newmortal();
	  if (pstr) {
	    len = strlen(pstr) + 1;

	    /*
	     * rl_extend_line_buffer() is not documented in the GNU
	     * Readline Library Manual Edition 2.1.  But Chet Ramey
	     * recommends me to use this function.
	     */
	    rl_extend_line_buffer(len);

	    Copy(pstr, rl_line_buffer, len, char);
	    sv_setpv(ST(0), rl_line_buffer);
	  }
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
	    warn("Gnu.xs:_rl_fetch_iostream: Illegal `id' value: `%d'", id);
	    XSRETURN_UNDEF;
	    break;
	  }
	}
	OUTPUT:
	RETVAL

Keymap
_rl_fetch_keymap(id)
	int id
	PROTOTYPE: $
	CODE:
	{
	  switch (id) {
	  case 0:
	    RETVAL = rl_executing_keymap;
	    break;
	  case 1:
	    RETVAL = rl_binding_keymap;
	    break;
	  default:
	    warn("Gnu.xs:_rl_fetch_keymap: Illegal `id' value: `%d'", id);
	    XSRETURN_UNDEF;
	    break;
	  }
	}
	OUTPUT:
	RETVAL

void
_rl_store_function(fn, id)
	SV *fn
	int id
	PROTOTYPE: $$
	CODE:
	{
	  /*
	   * If "fn" is undef, default value of the GNU Readline
	   * Library is set.
	   */
	  ST(0) = sv_newmortal();
	  if (id < 0 || id >= sizeof(fn_tbl)/sizeof(struct fn_vars)) {
	    warn("Gnu.xs:_rl_store_function: Illegal `id' value: `%d'", id);
	    XSRETURN_UNDEF;
	  }
	  
	  if (SvTRUE(fn)) {
	    /*
	     * Don't remove braces. The definition of SvSetSV() of
	     * Perl 5.003 has a problem.
	     */
	    if (fn_tbl[id].callback) {
	      SvSetSV(fn_tbl[id].callback, fn);
	    } else {
	      fn_tbl[id].callback = newSVsv(fn);
	    }
	    *(fn_tbl[id].rlfuncp) = fn_tbl[id].wrapper;
	  } else {
	    if (fn_tbl[id].callback) {
	      SvSetSV(fn_tbl[id].callback, &sv_undef);
	    }
	    *(fn_tbl[id].rlfuncp) = fn_tbl[id].defaultfn;
	  }

	  /* return variable value */
	  sv_setsv(ST(0), fn);
	}

void
_rl_fetch_function(id)
	int id
	PROTOTYPE: $
	CODE:
	{
	  ST(0) = sv_newmortal();
	  if (id < 0 || id >= sizeof(fn_tbl)/sizeof(struct fn_vars)) {
	    warn("Gnu.xs:_rl_fetch_function: Illegal `id' value: `%d'", id);
	    /* return undef */
	  } else if (fn_tbl[id].callback && SvTRUE(fn_tbl[id].callback))
	    sv_setsv(ST(0), fn_tbl[id].callback);
	}
