/*
 *	Gnu.xs --- GNU Readline wrapper module
 *
 *	$Id: Gnu.xs,v 1.71 1999-03-19 16:01:13 hayashi Exp $
 *
 *	Copyright (c) 1996-1999 Hiroo Hayashi.  All rights reserved.
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
 * Perl 5.005 requires an ANSI C Compiler.  Good news.
 * But I should still support legacy C compilers now.
 */
/* Adapted from BSD /usr/include/sys/cdefs.h. */
#if defined (__STDC__)
#  if !defined (__P)
#    define __P(protos) protos
#  endif
#else /* !__STDC__ */
#  if !defined (__P)
#    define __P(protos) ()
#  endif
#endif /* !__STDC__ */

/* from GNU Readline:xmalloc.c */
extern char *xmalloc __P((int));
extern char *tgetstr __P((const char *, char **));
#if (RLMAJORVER < 4)
void rl_extend_line_buffer __P((int));
#endif

/*
 * Using xfree() in GNU Readline Library causes problem with Solaris
 * 2.5.  It seems that the DLL mechanism of Solaris 2.5 links another
 * xfree() that does not do NULL argument check.
 * I choose this as default since some others OSs may have same problem.
 * usemymalloc=n is required.
 */
#ifdef OS2_USEDLL
/* from GNU Readline:xmalloc.c */
extern char *xfree __P((char *));

#else /* !OS2_USEDLL */
static void
xfree (string)
     char *string;
{
  if (string)
    free (string);
}
#endif /* !OS2_USEDLL */

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
 * from readline-4.0:complete.c
 * Redefine here since the function defined as static in complete.c.
 * This function is used for default vaule for rl_filename_quoting_function.
 */
static char * rl_quote_filename __P((char *s, int rtype, char *qcp));

static char *
rl_quote_filename (s, rtype, qcp)
     char *s;
     int rtype;
     char *qcp;
{
  char *r;

  r = xmalloc (strlen (s) + 2);
  *r = *rl_completer_quote_characters;
  strcpy (r + 1, s);
  if (qcp)
    *qcp = *rl_completer_quote_characters;
  return r;
}

#if (RLMAJORVER < 4)
/*
 * Before GNU Readline Library Version 4.0, rl_save_prompt() was
 * _rl_save_prompt and rl_restore_prompt() was _rl_restore_prompt().
 */
void rl_save_prompt() { _rl_save_prompt(); }
void rl_restore_prompt() { _rl_restore_prompt(); }

/*
 * Dummy functions
 */
void rl_cleanup_after_signal(){};
void rl_free_line_state(){};
void rl_reset_after_signal(){};
void rl_resize_terminal(){};
int rl_set_signals(){ 0; };
int rl_clear_signals(){ 0; };
#endif /* (RLMAJORVER < 4) */


/*
 *	string variable table for _rl_store_str(), _rl_fetch_str()
 */

static struct str_vars {
  char **var;
  int accessed;
  int read_only;
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

#if (RLMAJORVER < 4)
/* define dummy variable */
static int rl_erase_empty_line;
static int rl_catch_signals;
static int rl_catch_sigwinch;
#endif /* (RLMAJORVER < 4) */

static struct int_vars {
  int *var;
  int charp;
  int read_only;
} int_tbl[] = {
  { &rl_point,					0, 0 },	/* 0 */
  { &rl_end,					0, 0 },	/* 1 */
  { &rl_mark,					0, 0 },	/* 2 */
  { &rl_done,					0, 0 },	/* 3 */
  { &rl_pending_input,				0, 0 },	/* 4 */

  { &rl_completion_query_items,			0, 0 },	/* 5 */
  { &rl_completion_append_character,		0, 0 },	/* 6 */
  { &rl_ignore_completion_duplicates,		0, 0 },	/* 7 */
  { &rl_filename_completion_desired,		0, 0 },	/* 8 */
  { &rl_filename_quoting_desired,		0, 0 },	/* 9 */
  { &rl_inhibit_completion,			0, 0 },	/* 10 */

  { &history_base,				0, 0 },	/* 11 */
  { &history_length,				0, 0 },	/* 12 */
  { &max_input_history,				0, 1 },	/* 13 */
  { (int *)&history_expansion_char,		1, 0 },	/* 14 */
  { (int *)&history_subst_char,			1, 0 },	/* 15 */
  { (int *)&history_comment_char,		1, 0 },	/* 16 */
  { &history_quotes_inhibit_expansion,		0, 0 },	/* 17 */
  { &rl_erase_empty_line,			0, 0 },	/* 18 */
  { &rl_catch_signals,				0, 0 },	/* 19 */
  { &rl_catch_sigwinch,				0, 0 }	/* 20 */
};

/*
 *	function pointer variable table for _rl_store_function(),
 *	_rl_fetch_funtion()
 */

static int startup_hook_wrapper __P((void));
static int event_hook_wrapper __P((void));
static int getc_function_wrapper __P((FILE *));
static void redisplay_function_wrapper __P((void));
static char *completion_entry_function_wrapper __P((char *, int));
static char **attempted_completion_function_wrapper __P((char *, int, int));
static char *filename_quoting_function_wrapper __P((char *text, int match_type,
						    char *quote_pointer));
static char *filename_dequoting_function_wrapper __P((char *text,
						      int quote_char));
static int char_is_quoted_p_wrapper __P((char *text, int index));
static void ignore_some_completions_function_wrapper __P((char **matches));
static int directory_completion_hook_wrapper __P((char **textp));
static int history_inhibit_expansion_function_wrapper __P((char *str, int i));
static int pre_input_hook_wrapper __P((void));
static void completion_display_matches_hook_wrapper __P((char **matches,
							 int len, int max));

enum void_arg_func_type { STARTUP_HOOK, EVENT_HOOK, GETC_FN, REDISPLAY_FN,
			  CMP_ENT, ATMPT_COMP,
			  FN_QUOTE, FN_DEQUOTE, CHAR_IS_QUOTEDP,
			  IGNORE_COMP, DIR_COMP, HIST_INHIBIT_EXP,
			  PRE_INPUT_HOOK, COMP_DISP_HOOK
			};

#if (RLMAJORVER < 4)
/* define dummy variable */
static Function *rl_pre_input_hook;
static VFunction *rl_completion_display_matches_hook;
#endif /* (RLMAJORVER < 4) */

static struct fn_vars {
  Function **rlfuncp;		/* GNU Readline Library variable */
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
    (Function **)&rl_attempted_completion_function,		/* 5 */
    NULL,
    (Function *)attempted_completion_function_wrapper,
    NULL
  },
  {
    (Function **)&rl_filename_quoting_function,			/* 6 */
    (Function *)rl_quote_filename,
    (Function *)filename_quoting_function_wrapper,
    NULL
  },
  {
    (Function **)&rl_filename_dequoting_function,		/* 7 */
    NULL,
    (Function *)filename_dequoting_function_wrapper,
    NULL
  },
  {
    (Function **)&rl_char_is_quoted_p,				/* 8 */
    NULL,
    (Function *)char_is_quoted_p_wrapper,
    NULL
  },
  {
    (Function **)&rl_ignore_some_completions_function,		/* 9 */
    NULL,
    (Function *)ignore_some_completions_function_wrapper,
    NULL
  },
  {
    (Function **)&rl_directory_completion_hook,			/* 10 */
    NULL,
    (Function *)directory_completion_hook_wrapper,
    NULL
  },
  {
    (Function **)&history_inhibit_expansion_function,		/* 11 */
    NULL,
    (Function *)history_inhibit_expansion_function_wrapper,
    NULL
  },
  { &rl_pre_input_hook,	NULL,	pre_input_hook_wrapper,	NULL },	/* 12 */
  {
    (Function **)&rl_completion_display_matches_hook,		/* 13 */
    NULL,
    (Function *)completion_display_matches_hook_wrapper,
    NULL
  }
};

/*
 * Perl function wrappers
 */

static int void_arg_func_wrapper __P((int));

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
redisplay_function_wrapper()	{ return void_arg_func_wrapper(REDISPLAY_FN); }

static int
pre_input_hook_wrapper() { return void_arg_func_wrapper(PRE_INPUT_HOOK); }

static int
void_arg_func_wrapper(type)
     int type;
{
  dSP;
  int count;
  int ret;
  SV *svret;

  ENTER;
  SAVETMPS;

  PUSHMARK(sp);
  count = perl_call_sv(fn_tbl[type].callback, G_SCALAR);
  SPAGAIN;

  if (count != 1)
    croak("Gnu.xs:void_arg_func_wrapper: Internal error\n");

  svret = POPs;
  ret = SvIOK(svret) ? SvIV(svret) : -1;
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
 * call a perl function as rl_filename_quoting_function
 */

static char *
filename_quoting_function_wrapper(text, match_type, quote_pointer)
     char *text;
     int match_type;
     char *quote_pointer;
{
  dSP;
  int count;
  SV *replacement;
  char *str;
  
  ENTER;
  SAVETMPS;

  PUSHMARK(sp);
  if (text) {
    XPUSHs(sv_2mortal(newSVpv(text, 0)));
  } else {
    XPUSHs(&sv_undef);
  }
  XPUSHs(sv_2mortal(newSViv(match_type)));
  if (quote_pointer) {
    XPUSHs(sv_2mortal(newSVpv(quote_pointer, 0)));
  } else {
    XPUSHs(&sv_undef);
  }
  PUTBACK;

  count = perl_call_sv(fn_tbl[FN_QUOTE].callback, G_SCALAR);

  SPAGAIN;

  if (count != 1)
    croak("Gnu.xs:filename_quoting_function_wrapper: Internal error\n");

  replacement = POPs;
  str = SvOK(replacement) ? dupstr(SvPV(replacement, na)) : NULL;

  PUTBACK;
  FREETMPS;
  LEAVE;
  return str;
}

/*
 * call a perl function as rl_filename_dequoting_function
 */

static char *
filename_dequoting_function_wrapper(text, quote_char)
     char *text;
     int quote_char;
{
  dSP;
  int count;
  SV *replacement;
  char *str;
  
  ENTER;
  SAVETMPS;

  PUSHMARK(sp);
  if (text) {
    XPUSHs(sv_2mortal(newSVpv(text, 0)));
  } else {
    XPUSHs(&sv_undef);
  }
  XPUSHs(sv_2mortal(newSViv(quote_char)));
  PUTBACK;

  count = perl_call_sv(fn_tbl[FN_DEQUOTE].callback, G_SCALAR);

  SPAGAIN;

  if (count != 1)
    croak("Gnu.xs:filename_dequoting_function_wrapper: Internal error\n");

  replacement = POPs;
  str = SvOK(replacement) ? dupstr(SvPV(replacement, na)) : NULL;

  PUTBACK;
  FREETMPS;
  LEAVE;
  return str;
}

/*
 * call a perl function as rl_char_is_quoted_p
 */

static int
char_is_quoted_p_wrapper(text, index)
     char *text;
     int index;
{
  dSP;
  int count;
  int ret;
  
  ENTER;
  SAVETMPS;

  PUSHMARK(sp);
  if (text) {
    XPUSHs(sv_2mortal(newSVpv(text, 0)));
  } else {
    XPUSHs(&sv_undef);
  }
  XPUSHs(sv_2mortal(newSViv(index)));
  PUTBACK;

  count = perl_call_sv(fn_tbl[CHAR_IS_QUOTEDP].callback, G_SCALAR);

  SPAGAIN;

  if (count != 1)
    croak("Gnu.xs:char_is_quoted_p_wrapper: Internal error\n");

  ret = POPi;			/* warns unless integer */
  PUTBACK;
  FREETMPS;
  LEAVE;
  return ret;
}

/*
 * call a perl function as rl_ignore_some_completions_function
 */

static void
ignore_some_completions_function_wrapper(matches)
     char **matches;
{
  dSP;
  int i, l;
  AV *av_matches;
  
  /* copy C matches[] array into perl array */
  av_matches = newAV();

  /* matches[0] is the maximal matching substring.  So it may NULL, even rest
   * of matches[] has values. */
  if (matches[0]) {
    av_push(av_matches, sv_2mortal(newSVpv(matches[0], 0)));
    xfree(matches[0]);
  } else {
    av_push(av_matches, &sv_undef);
  }

  for (i = 1; matches[i]; i++)
    if (matches[i]) {
      av_push(av_matches, sv_2mortal(newSVpv(matches[i], 0)));
      xfree(matches[i]);
    } else {
      av_push(av_matches, &sv_undef);
    }

  PUSHMARK(sp);
  XPUSHs(newRV((SV *)av_matches)); /* push reference of array */
  PUTBACK;

  perl_call_sv(fn_tbl[IGNORE_COMP].callback, G_DISCARD);

  /* rebuild matches[] */
  l = av_len(av_matches) + 1;
  if (i < l)
    croak("Gnu.xs:ignore_some_completions_function_wrapper: matches array becomes longer.\n");

  for (i = 0; i < l; i++)
    matches[i] = dupstr(SvPV(av_shift(av_matches), na));
}

/*
 * call a perl function as rl_directory_completion_hook
 */

static int
directory_completion_hook_wrapper(textp)
     char **textp;
{
  dSP;
  int count;
  char *ret;
  
  ENTER;
  SAVETMPS;

  PUSHMARK(sp);
  if (textp && *textp) {
    XPUSHs(sv_2mortal(newSVpv(*textp, 0)));
  } else {
    XPUSHs(&sv_undef);
  }
  PUTBACK;

  count = perl_call_sv(fn_tbl[DIR_COMP].callback, G_SCALAR);

  SPAGAIN;

  if (count != 1)
    croak("Gnu.xs:directory_completion_hook_wrapper: Internal error\n");

  ret = POPp;			/* warns unless string */
  PUTBACK;
  FREETMPS;
  LEAVE;

  if (strcmp(*textp, ret) != 0) {
    xfree(*textp);
    *textp = dupstr(ret);
  }
}

/*
 * call a perl function as history_inhibit_expansion_function
 */

static int
history_inhibit_expansion_function_wrapper(text, index)
     char *text;
     int index;
{
  dSP;
  int count;
  int ret;
  
  ENTER;
  SAVETMPS;

  PUSHMARK(sp);
  if (text) {
    XPUSHs(sv_2mortal(newSVpv(text, 0)));
  } else {
    XPUSHs(&sv_undef);
  }
  XPUSHs(sv_2mortal(newSViv(index)));
  PUTBACK;

  count = perl_call_sv(fn_tbl[HIST_INHIBIT_EXP].callback, G_SCALAR);

  SPAGAIN;

  if (count != 1)
    croak("Gnu.xs:history_inhibit_expansion_function_wrapper: Internal error\n");

  ret = POPi;			/* warns unless integer */
  PUTBACK;
  FREETMPS;
  LEAVE;
  return ret;
}

#if (RLMAJORVER >= 4)
/*
 * call a perl function as rl_completion_display_matches_hook
 */

static void
completion_display_matches_hook_wrapper(matches, len, max)
     char **matches;
     int len;
     int max;
{
  dSP;
  int i, l;
  AV *av_matches;
  
  /* copy C matches[] array into perl array */
  av_matches = newAV();

  /* matches[0] is the maximal matching substring.  So it may NULL, even rest
   * of matches[] has values. */
  if (matches[0]) {
    av_push(av_matches, sv_2mortal(newSVpv(matches[0], 0)));
  } else {
    av_push(av_matches, &sv_undef);
  }

  for (i = 1; matches[i]; i++)
    if (matches[i]) {
      av_push(av_matches, sv_2mortal(newSVpv(matches[i], 0)));
    } else {
      av_push(av_matches, &sv_undef);
    }

  PUSHMARK(sp);
  XPUSHs(sv_2mortal(newRV((SV *)av_matches))); /* push reference of array */
  XPUSHs(sv_2mortal(newSViv(len)));
  XPUSHs(sv_2mortal(newSViv(max)));
  PUTBACK;

  perl_call_sv(fn_tbl[COMP_DISP_HOOK].callback, G_DISCARD);
}
#else /* (RLMAJORVER < 4) */
static void
completion_display_matches_hook_wrapper(matches, len, max)
     char **matches;
     int len;
     int max;
{
  /* dummy */
}
#endif /* (RLMAJORVER < 4) */

/*
 *	If you need more custom functions, define more funntion_wrapper_xx()
 *	and add entry on fntbl[].
 */

static int function_wrapper __P((int count, int key, int id));

static int fw_00(c, k) int c; int k; { return function_wrapper(c, k,  0); }
static int fw_01(c, k) int c; int k; { return function_wrapper(c, k,  1); }
static int fw_02(c, k) int c; int k; { return function_wrapper(c, k,  2); }
static int fw_03(c, k) int c; int k; { return function_wrapper(c, k,  3); }
static int fw_04(c, k) int c; int k; { return function_wrapper(c, k,  4); }
static int fw_05(c, k) int c; int k; { return function_wrapper(c, k,  5); }
static int fw_06(c, k) int c; int k; { return function_wrapper(c, k,  6); }
static int fw_07(c, k) int c; int k; { return function_wrapper(c, k,  7); }
static int fw_08(c, k) int c; int k; { return function_wrapper(c, k,  8); }
static int fw_09(c, k) int c; int k; { return function_wrapper(c, k,  9); }
static int fw_10(c, k) int c; int k; { return function_wrapper(c, k, 10); }
static int fw_11(c, k) int c; int k; { return function_wrapper(c, k, 11); }
static int fw_12(c, k) int c; int k; { return function_wrapper(c, k, 12); }
static int fw_13(c, k) int c; int k; { return function_wrapper(c, k, 13); }
static int fw_14(c, k) int c; int k; { return function_wrapper(c, k, 14); }
static int fw_15(c, k) int c; int k; { return function_wrapper(c, k, 15); }

static struct fnnode {
  Function *wrapper;		/* C wrapper function */
  SV *pfn;			/* Perl function */
} fntbl[] = {
  { fw_00,	NULL },
  { fw_01,	NULL },
  { fw_02,	NULL },
  { fw_03,	NULL },
  { fw_04,	NULL },
  { fw_05,	NULL },
  { fw_06,	NULL },
  { fw_07,	NULL },
  { fw_08,	NULL },
  { fw_09,	NULL },
  { fw_10,	NULL },
  { fw_11,	NULL },
  { fw_12,	NULL },
  { fw_13,	NULL },
  { fw_14,	NULL },
  { fw_15,	NULL }
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

static SV *callback_handler_callback = NULL;

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

#if (RLMAJORVER >= 2 && RLMINORVER >= 2 || RLMAJORVER > 2)

# rl_unbind_function_in_map() and rl_unbind_command_in_map() are introduced
# by readline-2.2.

int
_rl_unbind_function(function, map = rl_get_keymap())
	Function *function
	Keymap map
	PROTOTYPE: $;$
	CODE:
	{
	  RETVAL = rl_unbind_function_in_map(function, map);
	}
	OUTPUT:
	RETVAL

int
_rl_unbind_command(command, map = rl_get_keymap())
	char *command
	Keymap map
	PROTOTYPE: $;$
	CODE:
	{
	  RETVAL = rl_unbind_command_in_map(command, map);
	}
	OUTPUT:
	RETVAL

#endif /* readline-2.2 and later */

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
	      if (p) {
		sv_setpv(sv, (char *)p);
	      }
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

void
rl_save_prompt()
	PROTOTYPE:

void
rl_restore_prompt()
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

#if (RLMAJORVER >= 4)

void
rl_display_match_list(pmatches, plen = -1, pmax = -1)
	SV *pmatches
	int plen
	int pmax
	PROTOTYPE: $;$$
	CODE:
	{
	  int len, max, l, i;
	  char **matches;
	  AV *av_matches;
	  SV *pv, **pvp;

	  if (SvTYPE(SvRV(pmatches)) != SVt_PVAV) {
	    warn("Gnu.xs:_rl_display_match_list: the 1st arguments must be a reference of an array\n");
	    return;
	  }
	  av_matches = (AV *)SvRV(ST(0));
	  /* index zero contains possible match and is ignored */
	  if ((len = av_len(av_matches) + 1 - 1) == 0)
	    return;
	  matches = (char **)xmalloc (sizeof(char *) * (len + 2));
	  max = 0;
	  for (i = 1; i <= len; i++) {
	    pvp = av_fetch(av_matches, i, 0);
	    if (SvPOKp(*pvp)) {
	      matches[i] = dupstr(SvPV(*pvp, l));
	      if (l > max)
		max = l;
	    }
	  }
	  matches[len + 1] = NULL;

	  rl_display_match_list(matches,
				plen < 0 ? len : plen,
				pmax < 0 ? max : pmax);

	  for (i = 1; i <= len; i++)
	    xfree(matches[i]);
	  xfree(matches);
	}

#endif /* (RLMAJORVER < 4) */

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
	  if (cb_prompt) {
	    Safefree(cb_prompt);
	  }
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
#	2.5 Readline Signal Handling
#

void
rl_cleanup_after_signal()
	PROTOTYPE:

void
rl_free_line_state()
	PROTOTYPE:

void
rl_reset_after_signal()
	PROTOTYPE:

void
rl_resize_terminal()
	PROTOTYPE:

int
rl_set_signals()
	PROTOTYPE:

int
rl_clear_signals()
	PROTOTYPE:

#
#	2.6 Custom Completers
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

#  history_get_history_state() and history_set_history_state() are useless
#  and too dangerous
# void
# history_get_history_state()
# 	PROTOTYPE:
# 	PPCODE:
# 	{
# 	  HISTORY_STATE *state;
#
# 	  state = history_get_history_state();
# 	  EXTEND(sp, 4);
# 	  PUSHs(sv_2mortal(newSViv(state->offset)));
# 	  PUSHs(sv_2mortal(newSViv(state->length)));
# 	  PUSHs(sv_2mortal(newSViv(state->size)));
# 	  PUSHs(sv_2mortal(newSViv(state->flags)));
# 	  xfree((char *)state);
# 	}

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
	  if (entry) {
	    if (entry->line) {
	      sv_setpv(ST(0), entry->line);
	    }
	    xfree(entry->line);
	    xfree(entry->data);
	    xfree((char *)entry);
	  }
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
	  if (entry) {
	    if (entry->line) {
	      sv_setpv(ST(0), entry->line);
	    }
	    xfree(entry->line);
	    xfree(entry->data);
	    xfree((char *)entry);
	  }
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
unstifle_history()
	PROTOTYPE:

int
history_is_stifled()
	PROTOTYPE:

#
#	2.3.3 Information about the History List
#

# history_list() is implemented as a perl function in Gnu.pm.

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
	  if (entry && entry->line) {
	    sv_setpv(ST(0), entry->line);
	  }
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
	  if (entry && entry->line) {
	    sv_setpv(ST(0), entry->line);
	  }
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
	  if (entry && entry->line) {
	    sv_setpv(ST(0), entry->line);
	  }
	}

void
next_history()
	PROTOTYPE:
	CODE:
	{
	  HIST_ENTRY *entry;
	  entry = next_history();
	  ST(0) = sv_newmortal();
	  if (entry && entry->line) {
	    sv_setpv(ST(0), entry->line);
	  }
	}

#
#	2.3.5 Searching the History List
#
int
history_search(string, direction = -1)
	char *string
	int direction
	PROTOTYPE: $;$

int
history_search_prefix(string, direction = -1)
	char *string
	int direction
	PROTOTYPE: $;$

int
history_search_pos(string, direction = -1, pos = where_history())
	char *string
	int direction
	int pos
	PROTOTYPE: $;$$

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

#define DALLAR '$'		/* define for xsubpp bug */

char *
_history_arg_extract(line, first = 0 , last = DALLAR)
	char *line
	int first
	int last
	PROTOTYPE: $;$$
	CODE:
	{
	  RETVAL = history_arg_extract(first, last, line);
	}
	OUTPUT:
	RETVAL

void
_get_history_event(string, cindex, qchar = 0)
	char *string
	int cindex
	int qchar
	PROTOTYPE: $$;$
	PPCODE:
	{
	  char *text;

	  text = get_history_event(string, &cindex, qchar);
	  EXTEND(sp, 2);
	  if (text) {		/* don't free `text' */
	    PUSHs(sv_2mortal(newSVpv(text, 0)));
	  } else {
	    PUSHs(&sv_undef);
	  }
	  PUSHs(sv_2mortal(newSViv(cindex)));
	}

void
history_tokenize(text)
	char *text
	PROTOTYPE: $
	PPCODE:
	{
	  char **tokens;

	  tokens = history_tokenize(text);
	  if (tokens) {
	    int i, count;

	    /* count number of entries */
	    for (count = 0; tokens[count]; count++)
	      ;

	    EXTEND(sp, count);
	    for (i = 0; i < count; i++) {
	      PUSHs(sv_2mortal(newSVpv(tokens[i], 0)));
	      xfree(tokens[i]);
	    }
	    xfree((char *)tokens);
	  } else {
	    /* return null list */
	  }
	}


#
#	GNU Readline/History Library Variable Access Routines
#

MODULE = Term::ReadLine::Gnu		PACKAGE = Term::ReadLine::Gnu::Var

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

	  if (str_tbl[id].read_only) {
	    warn("Gnu.xs:_rl_store_str: store to read only variable");
	    XSRETURN_UNDEF;
	  }

	  /*
	   * Use xmalloc() and xfree() instead of New() and Safefree(),
	   * because this block may be reallocated by the GNU Readline Library.
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
	  if (*str_tbl[id].var) {
	    sv_setpv(ST(0), *str_tbl[id].var);
	  }
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
	     * Old manual did not document this function, but can be
	     * used.
	     */
	    rl_extend_line_buffer(len);

	    Copy(pstr, rl_line_buffer, len, char);
	    /* rl_line_buffer is not NULL here */
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
	    if (*(str_tbl[id].var)) {
	      sv_setpv(ST(0), *(str_tbl[id].var));
	    }
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

	  if (int_tbl[id].read_only) {
	    warn("Gnu.xs:_rl_store_int: store to read only variable");
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
	  } else if (fn_tbl[id].callback && SvTRUE(fn_tbl[id].callback)) {
	    sv_setsv(ST(0), fn_tbl[id].callback);
	  }
	}

MODULE = Term::ReadLine::Gnu		PACKAGE = Term::ReadLine::Gnu::XS

void
tgetstr(id)
	const char *id
	PROTOTYPE: $
	CODE:
	{
	  /*
	   * The magic number `2032' is derived from bash
	   * terminal.c:_rl_init_terminal_io().
	   */
	  char buffer[2032];
	  char *bp = buffer;

	  ST(0) = sv_newmortal();
	  if (id) {
	    sv_setpv(ST(0), tgetstr(id, &bp));
	  }
	}
