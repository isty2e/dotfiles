" Test double for vim-plug's declaration and installation boundary, not Git.
if exists('g:loaded_plug')
  finish
endif
let g:loaded_plug = 1
let g:vim_test_manager_source = 'downloaded'

function! plug#begin(home) abort
  let g:plug_home = a:home
  let g:plugs = {}
  command! -nargs=+ Plug call plug#(<args>)
  command! -nargs=* PlugInstall call s:Install(<q-args>)
endfunction

function! plug#(repo, ...) abort
  let name = fnamemodify(a:repo, ':t')
  let g:plugs[name] = extend({'dir': g:plug_home . '/' . name, 'uri': a:repo}, get(a:000, 0, {}))
endfunction

function! plug#end() abort
endfunction

function! s:Install(arguments) abort
  if $FAIL_INSTALL == '1'
    throw 'injected plugin installation failure'
  endif
  call writefile([a:arguments], $INSTALL_LOG, 'a')
endfunction
