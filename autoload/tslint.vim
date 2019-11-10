" File: tslint.vim
" Author: Shinya Ohyanagi <sohyanagi@gmail.com>
" WebPage: http://github.com/heavenshell/vim-tslint
" Description: Vim plugin for tslint
" License: BSD, see LICENSE for more details.
let s:save_cpo = &cpo
set cpo&vim

let g:tslint_ignore_warnings = get(g:, 'tslint_ignore_warnings', 1)
let g:tslint_enable_quickfix = get(g:, 'tslint_enable_quickfix', 0)
let g:tslint_callbacks = get(g:, 'tslint_callbacks', {})
let g:tslint_config = get(g:, 'tslint_config', '')
let g:tslint_use_tempname = get(g:, 'tslint_use_tempname', 0)

let s:tslint_bin = ''
let s:results = []
let s:warnings = []
let s:root_path = ''

function! s:detect_root(srcpath)
  if s:root_path == ''
    let s:root_path = finddir('node_modules', a:srcpath . ';')
  endif
  return s:root_path
endfunction

function! s:detect_tslint_bin(srcpath)
  let textlint = ''
  if executable('tslint') == 0
    let root_path = s:detect_root(a:srcpath)
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
          \ 'col': e['startPosition']['character'],
          \ 'vcol': 0,
          \ 'text': printf('[Tslint] %s %s', e['ruleName'], e['failure']),
          \ 'type': 'E',
          \ })
  endfor
  return results
endfunction

function! s:exit_cb(ch, msg, file, mode, winsaveview, tmpfile, bufnr, autofix)
  let warnings = s:parse_warnings(a:file)
  if g:tslint_ignore_warnings == 0
    cal setqflist(warnings, 'a')
  endif
  let file = a:file == '' ? expand('%s') : a:file
  let errors = s:parse_errors(file)
  call setqflist(errors, 'a')

  if a:autofix == 1
    let view = winsaveview()
    let lines = readfile(a:tmpfile)

    silent execute '% delete'
    call setline(1, lines)
    call winrestview(view)
  endif

  call delete(a:tmpfile)

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

function! s:buffer_to_file(file)
  let root_path = s:detect_root(a:file)
  if !s:tslint_bin
    let s:tslint_bin = s:detect_tslint_bin(a:file)
  endif
  if g:tslint_config == ''
    let g:tslint_config = s:detect_config(a:file)
  endif

  let ft = &filetype
  if ft !~ 'typescript'
    " Current window is not TypeScript buffer.
    let winid = a:0 > 1 ? a:2: win_getid()
    let ret = win_gotoid(winid)
    if !ret
      return
    endif
  endif

  let name = fnamemodify(a:file, ':t')
  if name == ''
    return
  endif
  " Tslint does not supprt STDIN.
  " Write current buffer to temp file and use it.
  if g:tslint_use_tempname == 1
    let t = tempname()
    let tmpfile = t . '_tslint_' . name
    call rename(t, tmpfile)
  else
    let dirname = fnamemodify(root_path, ':h')
    let tmpdir = printf('%s/.vim-tslint', dirname)
    if !isdirectory(tmpdir)
      call mkdir(tmpdir)
    endif
    let tmpfile = printf('%s/_tslint_%s', tmpdir, name)
  endif
  call writefile(getline(1, line('$')), tmpfile)

  return tmpfile
endfunction

function! s:send(job, input)
  let channel = job_getchannel(a:job)
  call ch_setoptions(channel, {'timeout': 2000})
  if ch_status(channel) ==# 'open'
    call ch_sendraw(channel, a:input)
    call ch_close_in(channel)
  endif
endfunction

function! tslint#run(...)
  if exists('s:job') && job_status(s:job) != 'stop'
    call job_stop(s:job)
  endif
  " echomsg '[Tslint] Start'

  let mode = a:0 > 0 ? a:1 : 'r'
  let s:results = []
  let s:warnings = []
  let file = expand('%:p')
  let tmpfile = s:buffer_to_file(file)

  let winsaveview = ''
  let bufnr = 0
  let cmd = printf('%s -c %s %s -t json', s:tslint_bin, g:tslint_config, tmpfile)
  let autofix = 0
  let s:job = job_start(cmd, {
        \ 'callback': {c, m -> s:callback(c, m)},
        \ 'exit_cb': {c, m -> s:exit_cb(c, m, file, mode, winsaveview, tmpfile, bufnr, autofix)},
        \ 'in_mode': 'nl',
        \ })
  call s:send(s:job, tmpfile)
endfunction

function! tslint#fix(...)
 if exists('s:job') && job_status(s:job) != 'stop'
    call job_stop(s:job)
  endif
  let mode = a:0 > 0 ? a:1 : 'r'
  let s:results = []
  let s:warnings = []
  let file = expand('%:p')
  let tmpfile = s:buffer_to_file(file)

  let winsaveview = winsaveview()
  let bufnr = bufnr('%')
  let cmd = printf('%s -c %s %s -t json --fix', s:tslint_bin, g:tslint_config, tmpfile)

  let autofix = 1
  let s:job = job_start(cmd, {
        \ 'callback': {c, m -> s:callback(c, m)},
        \ 'exit_cb': {c, m -> s:exit_cb(c, m, file, mode, winsaveview, tmpfile, bufnr, autofix)},
        \ 'in_mode': 'nl',
        \ })
  call s:send(s:job, tmpfile)
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
