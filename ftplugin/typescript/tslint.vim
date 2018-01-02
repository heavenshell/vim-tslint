" File: tslint.vim
" Author: Shinya Ohyanagi <sohyanagi@gmail.com>
" WebPage: http://github.com/heavenshell/vim-tslint
" Description: Vim plugin for tslint
" License: BSD, see LICENSE for more details.
let s:save_cpo = &cpo
set cpo&vim

if get(b:, 'loaded_tslint')
  finish
endif

" version check
if !has('channel') || !has('job')
  echoerr '+channel and +job are required for tslint.vim'
  finish
endif

command! -buffer Tslint :call tslint#run('a', win_getid())
noremap <silent> <buffer> <Plug>(Tslint) :Tslint <CR>

let b:loaded_tslint = 1

let &cpo = s:save_cpo
unlet s:save_cpo
