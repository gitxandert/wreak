" Shared helpers for the Wreak filetype.

let s:header = '^\%(code\|pseudo-\=code\|text\):\%(\s\|$\)'
let s:lang_flag = '\%(--language\%(\s\+\|=\)\|-l\s\+\)\(\S\+\)'

function! wreak#header_pattern() abort
  return s:header
endfunction

function! wreak#is_header(line) abort
  return a:line =~# s:header
endfunction

" A header that was typed on a carried-over indent: header-shaped, with
" nothing after the colon except --flags. It snaps to column 0 on Enter.
" (To keep a literal indented `text:` line, add anything else after it, e.g.
" a trailing comment.)
function! wreak#is_typed_header(line) abort
  return a:line =~# '^\s\+\%(code\|pseudo-\=code\|text\):\%(\s\+-\S.*\)\=\s*$'
endfunction

" Vim filetype for a `--language` name, or '' if unknown.
function! wreak#filetype_for(name) abort
  let l:map = extend(wreak#languages#map(), get(g:, 'wreak_language_map', {}))
  return get(l:map, tolower(a:name), '')
endfunction

" Unique `--language` names used by code blocks in buffer {buf}, in order.
function! wreak#used_languages(...) abort
  let l:buf = a:0 ? a:1 : bufnr('%')
  let l:seen = {}
  let l:out = []
  for l:line in getbufline(l:buf, 1, '$')
    if l:line !~# '^code:\%(\s\|$\)'
      continue
    endif
    let l:m = matchlist(l:line, '\s' . s:lang_flag)
    if !empty(l:m) && !has_key(l:seen, l:m[1])
      let l:seen[l:m[1]] = 1
      call add(l:out, l:m[1])
    endif
  endfor
  return l:out
endfunction

" Re-run the syntax file when the set of embedded languages changes, so a
" newly typed `--language rust` gets Rust highlighting without reopening.
function! wreak#refresh_syntax() abort
  let l:sig = join(wreak#used_languages(), ',')
  if l:sig !=# get(b:, 'wreak_lang_sig', '')
    let l:view = winsaveview()
    setlocal syntax=OFF
    setlocal syntax=wreak
    call winrestview(l:view)
  endif
endfunction
