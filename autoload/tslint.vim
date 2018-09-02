" File: tslint.vim
" Author: Shinya Ohyanagi <sohyanagi@gmail.com>
" WebPage: http://github.com/heavenshell/vim-tslint
" Description: Vim plugin for tslint
" License: BSD, see LICENSE for more details.
let s:save_cpo = &cpo
set cpo&vim

let g:tslint_ignore_warnings = get(g:, 'tslint_ignore_warnings', 1)
let g:tslint_ignore_prettier = get(g:, 'tslint_ignore_prettier', 1)
let g:tslint_enable_quickfix = get(g:, 'tslint_enable_quickfix', 0)
let g:tslint_callbacks = get(g:, 'tslint_callbacks', {})
let g:tslint_config = get(g:, 'tslint_config', '')
let s:tslint_bin = ''
let s:results = []
let s:warnings = []

function! s:detect_tslint_bin(srcpath)
  let textlint = ''
  if executable('tslint') == 0
    let root_path = finddir('node_modules', a:srcpath . ';')
    if root_path == ''
      return ''
    endif
    let root_path = fnamemodify(root_path, ':p')
    let tslint = exepath(root_path . '.bin/tslint')
  else
    let tslint = exepath('tslint')
  endif

  return tslint
endfunction

function! s:detect_config(srcpath)
  let config = findfile('tslint.json', a:srcpath . ';')
  if config == ''
    return ''
  endif
  return config
endfunction

function! s:parse_warnings(file)
  let results = []
  for w in s:warnings
    call add(results, {
          \ 'filename': a:file,
          \ 'lnum': 1,
          \ 'col': 0,
          \ 'vcol': 0,
          \ 'text': printf('[Tslint] %s', w),
          \ 'type': 'W',
          \ })
  endfor
  return results
endfunction

function! s:parse_errors(file)
  let results = []
  for e in s:results
    call add(results, {
          \ 'filename': a:file,
          \ 'lnum': e['startPosition']['line'] + 1,
          \ 'col': e['startPosition']['position'],
          \ 'vcol': 0,
          \ 'text': printf('[Tslint] %s %s', e['ruleName'], e['failure']),
          \ 'type': 'E',
          \ })
  endfor
  return results
endfunction

function! s:exit_cb(ch, msg, file, mode)
  let warnings = s:parse_warnings(a:file)
  cal setqflist(warnings, 'a')
  let errors = s:parse_errors(a:file)
  call setqflist(errors, 'a')

  if len(errors) == 0 && len(warnings) && len(getqflist()) == 0
    call setqflist([], 'r')
    cclose
  endif
  if has_key(g:tslint_callbacks, 'after_run')
    call g:tslint_callbacks['after_run'](a:ch, a:msg)
  endif
endfunction

function! s:callback(ch, msg)
  try
    let s:results = json_decode(a:msg)
  catch
    if g:tslint_ignore_warnings == 0
      " Maybe tslint.config warnings were raised.
      call add(s:warnings, a:msg)
    endif
  endtry
endfunction

function! tslint#run(...)
  if exists('s:job') && job_status(s:job) != 'stop'
    call job_stop(s:job)
  endif
  let s:results = []
  let s:warnings = []
  let file = expand('%:p')
  if !s:tslint_bin
    let s:tslint_bin = s:detect_tslint_bin(file)
  endif
  if g:tslint_config == ''
    let g:tslint_config = s:detect_config(file)
  endif
  let mode = a:0 > 0 ? a:1 : 'r'

  let ft = &filetype
  if ft !~ 'typescript'
    " Current window is not TypeScript buffer.
    let winid = a:0 > 1 ? a:2: win_getid()
    let ret = win_gotoid(winid)
    if !ret
      return
    endif
  endif

  " Tslint does not supprt STDIN.
  " Write current buffer to temp file and use it.
  let t = tempname()
  let ext = fnamemodify(file, ':e')
  let tmpfile = t . '_tslint.' . ext
  call rename(t, tmpfile)
  call writefile(getline(1, line('$')), tmpfile)

  let cmd = printf('%s -c %s %s -t json', s:tslint_bin, g:tslint_config, tmpfile)
  if g:tslint_ignore_prettier == 1
    let cmd = cmd . ' --fix'
  endif
  let s:job = job_start(cmd, {
        \ 'callback': {c, m -> s:callback(c, m)},
        \ 'exit_cb': {c, m -> s:exit_cb(c, m, file, mode)},
        \ 'in_io': 'buffer',
        \ 'in_name': file,
        \ })
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
