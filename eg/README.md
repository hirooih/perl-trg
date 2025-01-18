# `eg/` Directory

This directory includes examples using `Term::ReadLine::Gnu` module.

## Original Examples

### [`perlsh`](perlsh)

- A Perl REPL supporting line-editing and completion.  It can be used as a powerful calculator.

### [`pftp`](pftp)

- An ftp client with the GNU Readline support

### [`ptksh+`](ptksh+)

- A simple perl/Tk shell which demonstrates the callback functions

## Examples Imported from the GNU Readline Library Distribution

The following are ported from the examples in the GNU Readline Library distribution.

### [`rlversion`](rlversion)

- Print out readline's version number
- `rl_library_version`

### [`rlbasic`](rlbasic)

- A basic `readline()` loop example
- `rl_readline()`

### [`manexamp`](manexamp)

- 2.1 Basic Behavior: `rl_gets()`, 2.4.13 A Readline Example: `invert_case_line()`
- `rl_readline()`, `rl_modifying()`, `rl_initialize()`, `rl_add_defun()`, `rl_bind_key()`
- `rl_point`, `rl_end`, `rl_line_buffer`

### [`rltest`](rltest)

- `readline()` loop + `add_history()` + `history_list()`
- `rl_readline()`
- `add_history()`, `history_list()`

### [`rl`](rl)

- `rl_insert_text()`, `rl_readline()`
- `rl_startup_hook`, `rl_instream`, `rl_startup_hook`, `rl_num_chars_to_read`, `rl_event_hook`

### [`rlevent`](rlevent)

- `rl` + `rl_event_hook`

### [`rlkeymaps`](rlkeymaps)

- Tests for `keymap` functions
- `rl_make_keymap()`, `rl_set_keymap_name()`, `rl_get_keymap_by_name()`, `rl_copy_keymap()`

### [`histexamp`](histexamp)

- The GNU History Library example program
- `using_history()`, `history_expand()`, `add_history()`, `write_history()`, `read_history()`, `history_get_time()`, `history_get()`, `remove_history()`
- `history_length`, `history_base`

### [`rl-callbacktest`](rl-callbacktest)

- 2.4.14 Alternate Interface Example
- `rl_callback_handler_remove()`, `rl_callback_handler_install()`, `rl_resize_terminal()`, `rl_callback_read_char()`
- `add_history()`
- `rl_instream`

### [`rl-callbacktest2`](rl-callbacktest2)

- Provides readline()-like interface using the alternate interface
- `rl_callback_handler_remove()`, `rl_callback_handler_install()`, `ISSTATE()`, `rl_callback_read_char()`, `rl_free_line_state()`, `rl_callback_sigcleanup()`, `rl_cleanup_after_signal()`, `rl_bind_key()`
- `add_history()`
- `rl_readline_state`, `rl_instream`, `rl_catch_signals`

### [`rl-callbacktest3`](rl-callbacktest3)

- `rl-callbacktest` + `rl_getc()`, `rl_sigint_handler()` + `rl_getc_function`

### [`excallback`](excallback)

- Alternate interface + `rl_set_prompt()`
- `rl_add_defun()`, `rl_callback_handler_install()`, `rl_callback_read_char()`, `rl_set_prompt()`, `rl_redisplay()`
- `rl_line_buffer`, `rl_line_buf`
- `IO::Pty`, `POSIX::Termios`

### [`rlptytest`](rlptytest)

- Another alternate interface example using pty
- `rl_resize_terminal()`, `rl_callback_handler_install()`, `rl_reset_terminal()`, `rl_callback_read_char()`
- `add_history()`, `using_history()`, `read_history()`
- `rl_instream`, `rl_outstream`, `rl_deprep_term_function`
- `IO::Pty`, `POSIX::Termios`

### [`rl-timeout`](rl-timeout)

- Test various readline builtin timeouts
- `rl_set_timeout()`, `rl_readline()`, `ISSTATE()`, `rl_callback_handler_remove()`, `rl_callback_handler_install()`, `rl_timeout_remaining()`, `rl_callback_read_char()`
- `add_history()`
- `rl_instream`, `rl_timeout_event_hook`

### [`rlcat`](rlcat)

- `cat(1)` using readline
- `rl_variable_bind()`, `rl_readline()`

### [`fileman`](fileman)

- 2.6.4 A Short Completion Example: file manager example for readline library
- `MinLine()`, `AddHistory()`
- `rl_readline()`, `rl_completion_matches()`
- `rl_attempted_completion_function`
