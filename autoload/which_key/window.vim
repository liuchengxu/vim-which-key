let s:bufnr = -1
let s:winnr = -1

let s:use_popup = exists('*popup_create') && g:which_key_use_floating_win

function! which_key#window#open(runtime) abort
  let s:pos = [winsaveview(), winnr(), winrestcmd()]

  if s:use_popup
    if !exists('s:popup_id')
      let s:popup_id = popup_create([], {})
      call popup_hide(s:popup_id)
      call setbufvar(winbufnr(s:popup_id), '&filetype', 'which_key')
      call win_execute(s:popup_id, 'setlocal nonumber nowrap')
    endif
  else
    if g:which_key_use_floating_win
      call s:open_floating_win()
    else
      call s:split_or_new()
    endif

    setlocal filetype=which_key

    " Hides/restores cursor at the start/end of the guide, works in vim
    " Snippets from vim-game-code-break
    augroup which_key_cursor
      autocmd!
      execute 'autocmd BufLeave <buffer> set t_ve=' . escape(&t_ve, '|')
      execute 'autocmd VimLeave <buffer> set t_ve=' . escape(&t_ve, '|')
    augroup END
    setlocal t_ve=

    let s:winnr = winnr()
  endif

  call which_key#window#fill(a:runtime)
endfunction

function! s:open_floating_win() abort
  if !bufexists(s:bufnr)
    let s:bufnr = nvim_create_buf(v:false, v:false)
  endif
  " TODO should handle the layout better
  call nvim_open_win(
        \ s:bufnr, v:true,
        \ {
        \   'relative': 'editor',
        \   'row': &lines - 14,
        \   'col': 0,
        \   'width': &columns,
        \   'height': 120
        \ })

  if !hlexists('WhichKeyFloating')
    hi default link WhichKeyFloating Pmenu
  endif
  if exists('&winhighlight')
    setlocal winhighlight=Normal:WhichKeyFloating
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

function! s:append_prompt(rows) abort
  let rows = a:rows
  let prompt = which_key#trigger().'- '.which_key#window#name()
  let rows += ['', prompt]
  return rows
endfunction

function! s:show_popup(rows) abort
  let rows = s:append_prompt(a:rows)
  let col = &signcolumn ==# 'yes' ? 2 : 1
  let col += &number ? &numberwidth : 0
  call popup_move(s:popup_id, {
          \ 'line': &lines - len(rows) - &cmdheight,
          \ 'col': col
          \ })
  call popup_settext(s:popup_id, rows)
  call popup_show(s:popup_id)
endfunction

function! s:show_floating_win(rows, layout) abort
  let rows = s:append_prompt(a:rows)
  call nvim_buf_set_lines(s:bufnr, 0, -1, 0, rows)
  call nvim_win_set_config(
        \ win_getid(s:winnr),
        \ {
        \   'relative': 'editor',
        \   'row': &lines - nvim_buf_line_count(s:bufnr) - &cmdheight - 1,
        \   'col': 0,
        \   'width': &columns,
        \   'height': a:layout.win_dim + 2
        \ })
endfunction

function! which_key#window#fill(runtime) abort
  let runtime = a:runtime

  let s:name = get(runtime, 'name', '')

  let [layout, rows] = which_key#view#prepare(runtime)

  if s:use_popup
    call s:show_popup(rows)
  else
    if g:which_key_use_floating_win
      call s:show_floating_win(rows, layout)
    else
      let resize = g:which_key_vertical ? 'vertical resize' : 'resize'
      noautocmd execute resize layout.win_dim
      setlocal modifiable
      " Delete all lines in the buffer
      " Use black hole register to avoid affecting the normal registers. :h quote_
      silent 1,$delete _
      call setline(1, rows)
      setlocal nomodifiable
    endif
  endif

  call which_key#wait_for_input()
endfunction

function! which_key#window#close() abort
  if exists('s:popup_id')
    call popup_hide(s:popup_id)
  else
    noautocmd execute s:winnr.'wincmd w'
    if winnr() == s:winnr
      close!
      execute s:pos[-1]
      noautocmd execute s:pos[1].'wincmd w'
      call winrestview(s:pos[0])
      let s:winnr = -1
    endif
  endif
endfunction

function! which_key#window#name() abort
  return get(s:, 'name', '')
endfunction
