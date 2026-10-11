" Vim syntax file for Wreak (.wreak)
" Three block families, each with its own color family:
"   code:         teal   (or the embedded language's own colors with --language)
"   pseudo-code:  orange
"   text:         violet

if exists('b:current_syntax')
  finish
endif

syntax case match
syntax sync fromstart

" ------------------------------------------------------------------ top level
syntax match wreakComment /^#.*$/
syntax match wreakStray   /^\%(#\|\%(code\|pseudo-\=code\|text\):\%(\s\|$\)\)\@!\S.*$/

" Rest of a header line after the colon: flags and their values.
syntax match wreakHeaderArgs /\%(^\%(code\|pseudo-\=code\|text\):\)\@<=.*$/ contained
      \ contains=wreakFlag,wreakFlagValue
syntax match wreakFlag      /\%(\s\)\@<=--\=\a[-[:alnum:]_]*/ contained
syntax match wreakFlagValue /\%(--\=\a[-[:alnum:]_]*\%(=\|\s\+\)\)\@<=[^- \t]\S*/ contained

" ------------------------------------------------------------------ code (generic)
syntax region wreakCodeBlock matchgroup=wreakCodeHeader
      \ start=/^code:\%(\s\|$\)\@=/ end=/^\S\@=/ keepend
      \ contains=wreakHeaderArgs,wreakCodeString,wreakCodeNumber,wreakCodeComment
syntax match wreakCodeComment /\%(\/\/\|#\).*$/ contained
syntax match wreakCodeString  /"\%([^"\\]\|\\.\)*"\|'\%([^'\\]\|\\.\)*'\|`[^`]*`/ contained
syntax match wreakCodeNumber  /\<\%(0x\x\+\|\d\+\%(\.\d\+\)\=\)\>/ contained

" ------------------------------------------------------------------ code (embedded languages)
" For every `--language NAME` used in this buffer, include that language's
" syntax and give its blocks the language's own colors. Defined after the
" generic region so these take priority.
let b:wreak_lang_sig = join(wreak#used_languages(), ',')
let s:included = {}
let s:n = 0
for s:name in wreak#used_languages()
  let s:ft = wreak#filetype_for(s:name)
  if empty(s:ft)
    continue
  endif
  if !has_key(s:included, s:ft)
    if empty(globpath(&runtimepath, 'syntax/' . s:ft . '.vim'))
      continue
    endif
    unlet! b:current_syntax
    execute 'syntax include @wreakLang_' . s:ft . ' syntax/' . s:ft . '.vim'
    unlet! b:current_syntax
    syntax case match
    let s:included[s:ft] = 1
  endif
  let s:n += 1
  let s:pat = '^code:\ze\%(\s.*\)\=\s\%(--language\%(\s\+\|=\)\|-l\s\+\)'
        \ . '\V' . escape(s:name, '\/') . '\m\%(\s\|$\)'
  execute 'syntax region wreakCodeLang' . s:n . ' matchgroup=wreakCodeHeader'
        \ . ' start=/' . s:pat . '/ end=/^\S\@=/ keepend'
        \ . ' contains=wreakHeaderArgs,@wreakLang_' . s:ft
endfor
unlet! s:included s:n s:name s:ft s:pat

" ------------------------------------------------------------------ pseudo-code
syntax region wreakPseudoBlock matchgroup=wreakPseudoHeader
      \ start=/^pseudo-\=code:\%(\s\|$\)\@=/ end=/^\S\@=/ keepend
      \ contains=wreakHeaderArgs,wreakPseudoComment,wreakPseudoString,wreakPseudoNumber,
      \wreakPseudoConstant,wreakPseudoKeyword,wreakPseudoFunction,wreakPseudoType,wreakPseudoOperator
syntax match   wreakPseudoComment  /\%(\/\/\|#\).*$/ contained
syntax match   wreakPseudoString   /"\%([^"\\]\|\\.\)*"\|'\%([^'\\]\|\\.\)*'/ contained
syntax match   wreakPseudoNumber   /\<\d\+\%(\.\d\+\)\=\>/ contained
syntax match   wreakPseudoFunction /\<\h\w*\ze\s*(/ contained
syntax match   wreakPseudoType     /\<\u\w*\>/ contained
syntax match   wreakPseudoOperator /<-\|->\|=>\|:=\|==\|!=\|<=\|>=\|&&\|||\|[-+*\/%=<>!]/ contained
syntax case ignore
syntax keyword wreakPseudoConstant contained true false null nil none undefined
syntax keyword wreakPseudoKeyword  contained
      \ if else elif elseif then end endif for foreach each in of while do until
      \ repeat loop return returns break continue function func fn def procedure
      \ proc method class struct type interface trait enum module import from
      \ export let var const set call new try catch except finally throw raise
      \ match case when switch default async await yield and or not is with as
      \ given on emit
syntax case match

" ------------------------------------------------------------------ text
syntax region wreakTextBlock matchgroup=wreakTextHeader
      \ start=/^text:\%(\s\|$\)\@=/ end=/^\S\@=/ keepend
      \ contains=wreakHeaderArgs,wreakTextCode,wreakTextBold,wreakTextRequirement
syntax match wreakTextCode        /`[^`]\+`/ contained
syntax match wreakTextBold        /\*\*[^*]\+\*\*/ contained
syntax match wreakTextRequirement
      \ /\<\%(MUST NOT\|MUST\|SHOULD NOT\|SHOULD\|NEVER\|ALWAYS\|DO NOT\|DON'T\|REQUIRED\|OPTIONAL\)\>/ contained

" ------------------------------------------------------------------ colors
" Explicit defaults so the three families are always distinct regardless of
" colorscheme. Override any group in your config, e.g.
"   highlight wreakTextBlock guifg=#d0b0ff
function! s:highlight() abort
  hi def wreakCodeHeader      gui=bold cterm=bold guifg=#2AA198 ctermfg=36
  hi def wreakCodeBlock       guifg=#2AA198 ctermfg=36
  hi def wreakCodeString      guifg=#6CC4B8 ctermfg=79
  hi def link wreakCodeNumber wreakCodeString
  hi def wreakCodeComment     gui=italic cterm=italic guifg=#5F8F8A ctermfg=66

  hi def wreakPseudoHeader    gui=bold cterm=bold guifg=#CB7B16 ctermfg=172
  hi def wreakPseudoBlock     guifg=#CB7B16 ctermfg=172
  hi def wreakPseudoKeyword   gui=bold cterm=bold guifg=#E0952B ctermfg=214
  hi def link wreakPseudoOperator wreakPseudoKeyword
  hi def wreakPseudoFunction  guifg=#D9A441 ctermfg=179
  hi def link wreakPseudoType wreakPseudoFunction
  hi def wreakPseudoString    guifg=#C9A15A ctermfg=180
  hi def link wreakPseudoNumber   wreakPseudoString
  hi def link wreakPseudoConstant wreakPseudoString
  hi def wreakPseudoComment   gui=italic cterm=italic guifg=#9A7A55 ctermfg=137

  hi def wreakTextHeader      gui=bold cterm=bold guifg=#8E6CD8 ctermfg=98
  hi def wreakTextBlock       guifg=#8E6CD8 ctermfg=98
  hi def link wreakStray      wreakTextBlock
  hi def wreakTextCode        guifg=#B49CF0 ctermfg=147
  hi def wreakTextBold        gui=bold cterm=bold guifg=#A585F0 ctermfg=141
  hi def link wreakTextRequirement wreakTextBold

  hi def wreakFlag            guifg=#808080 ctermfg=244
  hi def wreakFlagValue       gui=italic cterm=italic guifg=#A0A0A0 ctermfg=248
  hi def link wreakComment    Comment
endfunction
call s:highlight()

augroup wreak_colors
  autocmd!
  autocmd ColorScheme * call s:highlight()
augroup END

let b:current_syntax = 'wreak'
