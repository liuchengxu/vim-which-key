let s:bufnr = -1
let s:winnr = -1

let s:use_popup = exists('*popup_create') && g:which_key_use_floating_win

if !hlexists('WhichKeyFloating')
  hi default link WhichKeyFloating Pmenu
endif

function! s:hide_cursor() abort
  " Hides/restores cursor at the start/end of the guide, works in vim
  " Snippets from vim-game-code-break
  augroup which_key_cursor
    autocmd!
    execute 'autocmd BufLeave <buffer> set t_ve=' . escape(&t_ve, '|')
    execute 'autocmd VimLeave <buffer> set t_ve=' . escape(&t_ve, '|')
  augroup END
  setlocal t_ve=
endfunction

function! s:append_prompt(rows) abort
  let rows = a:rows
  let prompt = which_key#trigger().'- '.which_key#window#name()
  call add(rows, prompt)
  return rows
endfunction

function! s:floating_win_col_offset() abort
  if g:which_key_disable_default_offset
    return 1
  else
    return (&number ? strlen(line('$')) : 0) + (&signcolumn ==# 'yes' ? 2: 0) + 1
  endif
endfunction

function! s:apply_custom_floating_opts(opts) abort
  let opts = a:opts
  if exists('g:which_key_floating_opts')
    for [key, val] in items(g:which_key_floating_opts)
      if has_key(opts, key)
        let opts[key] = opts[key] + eval('0'.val)
      endif
    endfor
  endif
  return opts
endfunction

let s:page_size = 10

function! s:paginate(rows) abort
  if len(a:rows) <= s:page_size
    return a:rows
  endif

  let s:total_rows = a:rows
  let s:total_pages = len(a:rows) / s:page_size + 1
  let s:cur_page_number = 1

  let page_rows = a:rows[ : s:cur_page_number * s:page_size]
  return page_rows
endfunction

function! s:show_page(start, end) abort
  let page_rows = s:total_rows[a:start : a:end]
  call s:show_with_page_info(page_rows)
  call s:wait_for_input()
endfunction

function! which_key#window#show_next_page() abort
  if s:cur_page_number == s:total_pages
    call s:wait_for_input()
    return
  endif

  let start = s:cur_page_number * s:page_size
  let end = (s:cur_page_number + 1) * s:page_size
  let s:cur_page_number += 1
  call s:show_page(start, end)
endfunction

function! which_key#window#show_prev_page() abort
  if s:cur_page_number == 1
    call s:wait_for_input()
    return
  endif

  let start = (s:cur_page_number - 2) * s:page_size
  let end = (s:cur_page_number - 1) * s:page_size
  let s:cur_page_number -= 1
  call s:show_page(start, end)
endfunction

function! s:apply_append_extra(rows) abort
  let prompt = which_key#trigger().'- '.which_key#window#name()
  " TODO: allow C-N/P configurable?
  let rows = add(a:rows, printf('%s (%d/%d) [C-N] Next Page [C-P] Prev Page', prompt, s:cur_page_number, s:total_pages))
  return rows
endfunction

function! s:append_extra(rows) abort
  if !exists('s:cur_page_number')
    return a:rows
  endif
  if s:cur_page_number == s:total_pages
    return s:apply_append_extra(a:rows)
  elseif len(a:rows) <= s:page_size
    let rows = s:append_prompt(a:rows)
  elseif s:cur_page_number < s:total_pages
    return s:apply_append_extra(a:rows)
  endif
  return rows
endfunction

if s:use_popup

  function! s:show_popup(rows) abort
    if !exists('s:popup_id')
      let s:popup_id = popup_create([], {'highlight': 'WhichKeyFloating'})
      call popup_hide(s:popup_id)
      call setbufvar(winbufnr(s:popup_id), '&filetype', 'which_key')
      call win_execute(s:popup_id, 'setlocal nonumber nowrap')
    endif

    let offset = s:floating_win_col_offset()
    if g:which_key_floating_relative_win
      let col = offset + win_screenpos(g:which_key_origin_winid)[1]
      let maxwidth = winwidth(g:which_key_origin_winid) - offset - 1
    else
      let col = offset
      let maxwidth = &columns - offset - 1
    endif
    call popup_move(s:popup_id, {
            \ 'col': col,
            \ 'line': &lines - len(a:rows) - &cmdheight,
            \ 'maxwidth': maxwidth,
            \ 'minwidth': maxwidth,
            \ })
    call popup_settext(s:popup_id, a:rows)
    call popup_show(s:popup_id)
  endfunction

  function! s:show_with_page_info(rows) abort
    let rows = s:append_extra(a:rows)
    call s:show_popup(rows)
  endfunction

  function! s:show(rows) abort
    let rows = s:append_prompt(a:rows)
    call s:show_popup(rows)
  endfunction

elseif g:which_key_use_floating_win

  function! s:show_floating_win(rows) abort
    if !bufexists(s:bufnr) || !nvim_buf_is_valid(s:bufnr)
      let s:bufnr = nvim_create_buf(v:false, v:false)
    endif

    silent call nvim_buf_set_lines(s:bufnr, 0, -1, 0, a:rows)

    let row_offset = &cmdheight + (&laststatus > 0 ? 1 : 0)

    let opts = {
          \ 'row': &lines - nvim_buf_line_count(s:bufnr) - row_offset,
          \ 'height': len(a:rows),
          \ }

    if g:which_key_disable_default_offset
      let s:origin_lnum_width = 0
    else
      if !exists('s:origin_lnum_width')
        let s:origin_lnum_width = strlen(string(line('$')))
      endif
    endif

    if g:which_key_floating_relative_win
      let opts.col = s:origin_lnum_width
      let opts.width = winwidth(g:which_key_origin_winid) - opts.col
      let opts.win = g:which_key_origin_winid
      let opts.relative = 'win'
    else
      let opts.col = s:origin_lnum_width
      let opts.width = &columns - opts.col
      let opts.relative = 'editor'
    endif

    let opts = s:apply_custom_floating_opts(opts)

    if exists('s:floating_winid') && nvim_win_is_valid(s:floating_winid)
      call nvim_win_set_config(s:floating_winid, opts)
    else
      silent let s:floating_winid = nvim_open_win(s:bufnr, v:true, opts)
      call s:hide_cursor()
      call setbufvar(s:bufnr, '&filetype', 'which_key')
      call setwinvar(s:floating_winid, '&winhl', 'Normal:WhichKeyFloating')
    endif
  endfunction

  function! s:show_with_page_info(rows) abort
    let rows = s:append_extra(a:rows)
    call s:show_floating_win(a:rows)
  endfunction

  function! s:show(rows) abort
    let rows = s:append_prompt(a:rows)
    call s:show_floating_win(a:rows)
  endfunction

else

  function! s:split_or_new() abort
    let position = g:which_key_position ==? 'topleft' ? 'topleft' : 'botright'

    if g:which_key_use_floating_win
      let qfbuf = &buftype ==# 'quickfix'
      let splitcmd = g:which_key_vertical ? '1vsplit' : '1split'
      noautocmd execute 'keepjumps' position splitcmd '+buffer'.s:bufnr
      cmapclear <buffer>
      if qfbuf
        noautocmd execute bufnr('%').'bwipeout!'
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

  function! s:open_split_win() abort
    let s:pos = [winsaveview(), winnr(), winrestcmd()]
    call s:split_or_new()
    call s:hide_cursor()
    setlocal filetype=which_key
    let s:winnr = winnr()
  endfunction

  function! s:close_split_win() abort
    noautocmd execute s:winnr.'wincmd w'
    if winnr() == s:winnr
      close!
      execute s:pos[-1]
      noautocmd execute s:pos[1].'wincmd w'
      call winrestview(s:pos[0])
      let s:winnr = -1
    endif
  endfunction

  function! s:show_old_win(rows) abort
    if s:winnr == -1
      call s:open_split_win()
    endif

    let resize = g:which_key_vertical ? 'vertical resize' : 'resize'
    noautocmd execute resize len(a:rows)
    setlocal modifiable
    " Delete all lines in the buffer
    " Use black hole register to avoid affecting the normal registers. :h quote_
    silent 1,$delete _
    call setline(1, a:rows)
    setlocal nomodifiable
  endfunction

  function! s:show_with_page_info(rows) abort
    call s:show_old_win(a:rows)
    " TODO: echo extra
  endfunction

  function! s:show(rows) abort
    call s:show_old_win(a:rows)
  endfunction

endif

function! s:wait_for_input() abort
  try
    call which_key#wait_for_input()
  catch /^Vim\%((\a\+)\)\=:E132/
    echoerr "E132:".v:exception.', throwpoint:'.v:throwpoint
    call which_key#wait_for_input()
  endtry
endfunction

function! which_key#window#show(runtime) abort
  let s:name = get(a:runtime, 'name', '')
  let [s:_layout, rows] = which_key#renderer#prepare(a:runtime)
  if g:which_key_enable_paginate
    call s:show_with_page_info(s:paginate(rows))
  else
    call s:show(rows)
  endif
  call s:wait_for_input()
endfunction

function! which_key#window#close() abort
  if exists('s:origin_lnum_width')
    unlet s:origin_lnum_width
  endif

  if exists('s:floating_winid')
    silent! call nvim_win_close(s:floating_winid, v:true)
    unlet s:floating_winid
    return
  endif

  if exists('s:popup_id')
    call popup_close(s:popup_id)
    unlet s:popup_id
  else
    call s:close_split_win()
  endif
endfunction

function! which_key#window#name() abort
  return get(s:, 'name', '')
endfunction
