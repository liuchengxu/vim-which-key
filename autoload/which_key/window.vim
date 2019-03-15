let s:bufnr = -1
let s:winnr = -1

function! which_key#window#open(runtime) abort
  let s:pos = [winsaveview(), winnr(), winrestcmd()]
  call s:open_win()
  call which_key#window#fill(a:runtime)
endfunction

function! s:open_win() abort

  if g:which_key_use_floating_win
    call s:open_floating_win()
  else
    call s:split_or_new()
  endif

  setlocal filetype=which_key

  let s:winnr = winnr()

  " Hides/restores cursor at the start/end of the guide, works in vim
  " Snippets from vim-game-code-break
  augroup which_key_cursor
    autocmd!
    execute 'autocmd BufLeave <buffer> set t_ve=' . escape(&t_ve, '|')
    execute 'autocmd VimLeave <buffer> set t_ve=' . escape(&t_ve, '|')
  augroup END
  setlocal t_ve=
endfunction

function! s:open_floating_win() abort
  if !bufexists(s:bufnr)
    let s:bufnr = nvim_create_buf(v:false, v:false)
  endif
  " TODO should handle the layout better
  call nvim_open_win(
        \ s:bufnr, v:true, &columns, 120,
        \ {
        \   'relative': 'editor',
        \   'row': &lines - 14,
        \   'col': 0
        \ })

  if exists('&winhighlight')
    setlocal winhighlight=Normal:Pmenu
  endif
endfunction

function! s:split_or_new() abort
  let position = g:which_key_position ==? 'topleft' ? 'topleft' : 'botright'

  if g:which_key_use_floating_win
    let qfbuf = &buftype ==# 'quickfix'
    let splitcmd = g:which_key_vertical ? '1vsplit' : '1split'
    noautocmd execute 'keepjumps' position splitcmd '+buffer'.s:bufnr
    cmapclear <buffer>
    if qfbuf
      let bnum = bufnr('%')
      noautocmd execute bnum.'bwipeout!'
    endif
  else
    let splitcmd = g:which_key_vertical ? '1vnew' : '1new'
    noautocmd execute 'keepjumps' position splitcmd
    let s:bufnr = bufnr('%')
    augroup which_key_leave
      autocmd!
      autocmd WinLeave <buffer> call which_key#window#close()
    augroup END
  endif
endfunction

function! which_key#window#fill(runtime) abort
  let runtime = a:runtime

  let s:name = get(runtime, 'name', '')

  let [layout, rows] = which_key#view#prepare(runtime)

  if g:which_key_use_floating_win
    call nvim_win_config(
          \ win_getid(s:winnr), &columns, layout.win_dim + 2,
          \ {
          \   'relative': 'editor',
          \   'row': &lines - layout.win_dim - 4,
          \   'col': 0
          \ })
    let prompt = which_key#trigger().'- '.which_key#window#name()
    let rows += ['', prompt]
  else
    let resize = g:which_key_vertical ? 'vertical resize' : 'resize'
    noautocmd execute resize layout.win_dim
  endif

  setlocal modifiable
  " Delete all lines in the buffer
  " Use black hole register to avoid affecting the normal registers. :h quote_
  silent 1,$delete _
  call setline(1, rows)
  setlocal nomodifiable

  call which_key#wait_for_input()
endfunction

function! which_key#window#close() abort
  noautocmd execute s:winnr.'wincmd w'
  if winnr() == s:winnr
    close!
    execute s:pos[-1]
    noautocmd execute s:pos[1].'wincmd w'
    call winrestview(s:pos[0])
    let s:winnr = -1
  endif
endfunction

function! which_key#window#name() abort
  return get(s:, 'name', '')
endfunction
