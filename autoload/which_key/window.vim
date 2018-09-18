let s:bufnr = -1
let s:winnr = -1

function! which_key#window#open(runtime) abort
  let s:pos = [winsaveview(), winnr(), winrestcmd()]

  let s:name = get(a:runtime, 'name', '')

  call s:open()

  let runtime = a:runtime
  let layout = which_key#util#calc_layout(runtime)
  let rows = which_key#util#create_string(layout, runtime)

  let resize = g:which_key_vertical ? 'vertical resize' : 'resize'
  noautocmd execute resize layout.win_dim

  call setline(1, rows)

  call which_key#wait_for_input()
endfunction

function! s:open() abort
  let position = g:which_key_position ==? 'topleft' ? 'topleft' : 'botright'

  if bufexists(s:bufnr)
    let qfbuf = &buftype ==# 'quickfix'
    let splitcmd = g:which_key_vertical ? '1vs' : '1sp'
    noautocmd execute 'keepjumps' position splitcmd
    let bnum = bufnr('%')
    noautocmd execute 'buffer' s:bufnr
    cmapclear <buffer>
    if qfbuf
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
  return s:name
endfunction
