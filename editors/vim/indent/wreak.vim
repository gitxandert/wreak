if exists('b:did_indent')
  finish
endif
let b:did_indent = 1

setlocal indentexpr=WreakIndent(v:lnum)
setlocal indentkeys=o,O,*<CR>,!^F
let b:undo_indent = 'setlocal indentexpr< indentkeys<'

if exists('*WreakIndent')
  finish
endif

function! WreakIndent(lnum) abort
  let l:line = getline(a:lnum)

  " Headers and comments always live at column 0. A header typed on a
  " carried-over indent snaps back when Enter is pressed.
  if wreak#is_header(l:line) || l:line =~# '^#' || wreak#is_typed_header(l:line)
    return 0
  endif

  " Re-indenting an existing body line (e.g. `=`): keep its own indentation so
  " nested code is not flattened.
  if l:line =~# '^\s\+\S'
    return indent(a:lnum)
  endif

  let l:prev = prevnonblank(a:lnum - 1)
  if l:prev == 0
    return 0
  endif
  let l:pline = getline(l:prev)

  " First line after a header: one tab.
  if wreak#is_header(l:pline)
    return shiftwidth()
  endif
  " Inside a block: continue at the previous line's depth.
  if l:pline =~# '^\s'
    return indent(l:prev)
  endif
  " After a comment or stray column-0 text: stay at column 0.
  return 0
endfunction
