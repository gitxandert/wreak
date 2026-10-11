if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

" Block bodies are tab-delimited: real tabs, one level per Enter after a header.
setlocal noexpandtab tabstop=4 shiftwidth=0 softtabstop=0 autoindent
setlocal comments=:# commentstring=#\ %s
setlocal formatoptions-=t formatoptions+=croql
setlocal wrap linebreak

augroup wreak_refresh
  autocmd! * <buffer>
  autocmd InsertLeave,BufWritePost,TextChanged <buffer> call wreak#refresh_syntax()
augroup END

let b:undo_ftplugin = 'setlocal expandtab< tabstop< shiftwidth< softtabstop< autoindent<'
      \ . ' comments< commentstring< formatoptions< wrap< linebreak<'
      \ . ' | execute "autocmd! wreak_refresh * <buffer>"'
