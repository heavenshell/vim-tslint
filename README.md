# vim-tslint

An asynchronous Tslint for Vim.

![Realtime style check](./assets/vim-tslint.gif)


![Realtime style check with tsuquyomi](./assets/vim-tslint-tsuquyomi.gif)

## Invoke manually

Open TypeScript file and just execute `:Tslint`.

## Automatically lint on save

```viml
autocmd BufWritePost *.ts,*.tsx call tslint#run('a', get_winid())
```

## Integrate with Tsuquyomi

You can use Tsuquyomi's `TsuquyomiGeterr` and Tslint.
Set followings to your vimrc.

```viml
augroup tslint
  function! s:typescript_after(ch, msg)
    let cnt = len(getqflist())
    if cnt > 0
      echomsg printf('[Tslint] %s errors', cnt)
    endif
  endfunction
  let g:tslint_callbacks = {
    \ 'after_run': function('s:typescript_after')
    \ }

  let g:tsuquyomi_disable_quickfix = 1

  function! s:ts_quickfix()
    let winid = win_getid()
    call setqflist([], 'r')
    execute ':TsuquyomiGeterr'
    call tslint#run('a', winid)
  endfunction

  autocmd BufWritePost *.ts,*.tsx silent! call s:ts_quickfix()
  autocmd InsertLeave *.ts,*.tsx silent! call s:ts_quickfix()
augroup END
```

## License

New BSD License
