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

function! s:append_prompt(rows) abort
  let rows = a:rows
  let prompt = which_key#trigger().'- '.which_key#window#name()
  let rows += ['', prompt]
  return rows
endfunction

function! s:floating_win_col_offset() abort
  if g:which_key_disable_default_offset
    return 0
  else
    return (&number ? strlen(line('$')) : 0) + (&signcolumn ==# 'yes' ? 2: 0)
  endif
endfunction

function! s:show_popup(rows) abort
  if !exists('s:popup_id')
    let s:popup_id = popup_create([], {'highlight': 'WhichKeyFloating'})
    call popup_hide(s:popup_id)
    call setbufvar(winbufnr(s:popup_id), '&filetype', 'which_key')
    call win_execute(s:popup_id, 'setlocal nonumber nowrap')
  endif

  let rows = s:append_prompt(a:rows)
  let offset = s:floating_win_col_offset()
  if g:which_key_floating_relative_win
    let col = offset + win_screenpos(g:which_key_origin_winid)[1] + 1
    let maxwidth = winwidth(g:which_key_origin_winid) - offset
  else
    let col = offset + 1
    let maxwidth = &columns - offset
  endif
  call popup_move(s:popup_id, {
          \ 'col': col,
          \ 'line': &lines - len(rows) - &cmdheight,
          \ 'maxwidth': maxwidth,
          \ 'minwidth': maxwidth,
          \ })
  call popup_settext(s:popup_id, rows)
  call popup_show(s:popup_id)
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

function! s:show_floating_win(rows, layout) abort
  let rows = s:append_prompt(a:rows)

  if !bufexists(s:bufnr)
    let s:bufnr = nvim_create_buf(v:false, v:false)
  endif

  silent call nvim_buf_set_lines(s:bufnr, 0, -1, 0, rows)

  let row_offset = &cmdheight + (&laststatus > 0 ? 1 : 0)

  let opts = {
        \ 'row': &lines - nvim_buf_line_count(s:bufnr) - row_offset,
        \ 'height': a:layout.win_dim + 2,
        \ }

  if !exists('s:origin_lnum_width')
    let s:origin_lnum_width = strlen(string(line('$')))
  endif

  if g:which_key_floating_relative_win
    let opts.col = g:which_key_disable_default_offset ? 0 : s:origin_lnum_width
    let opts.width = winwidth(g:which_key_origin_winid) - opts.col
    let opts.win = g:which_key_origin_winid
    let opts.relative = 'win'
  else
    let opts.col = g:which_key_disable_default_offset ? 0 : s:origin_lnum_width
    let opts.width = &columns - opts.col
    let opts.relative = 'editor'
  endif

  let opts = s:apply_custom_floating_opts(opts)

  if !exists('s:floating_winid')
    silent let s:floating_winid = nvim_open_win(s:bufnr, v:true, opts)
    call s:hide_cursor()
    call setbufvar(s:bufnr, '&ft', 'which_key')
    call setwinvar(s:floating_winid, '&winhl', 'Normal:WhichKeyFloating')
  else
    call nvim_win_set_config(s:floating_winid, opts)
  endif
endfunction

function! s:show_old_win(rows, layout) abort
  if s:winnr == -1
    call s:open_split_win()
  endif

  let resize = g:which_key_vertical ? 'vertical resize' : 'resize'
  noautocmd execute resize a:layout.win_dim
  setlocal modifiable
  " Delete all lines in the buffer
  " Use black hole register to avoid affecting the normal registers. :h quote_
  silent 1,$delete _
  call setline(1, a:rows)
  setlocal nomodifiable
endfunction

function! which_key#window#show(runtime) abort
  let s:name = get(a:runtime, 'name', '')
  let [layout, rows] = which_key#renderer#prepare(a:runtime)

  if s:use_popup
    call s:show_popup(rows)
  elseif g:which_key_use_floating_win
    call s:show_floating_win(rows, layout)
  else
    call s:show_old_win(rows, layout)
  endif

  call which_key#wait_for_input()
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

function! which_key#window#close() abort
  if exists('s:origin_lnum_width')
    unlet s:origin_lnum_width
  endif

  if exists('s:floating_winid')
    call nvim_win_close(s:floating_winid, v:true)
    unlet s:floating_winid
  elseif exists('s:popup_id')
    call popup_close(s:popup_id)
    unlet s:popup_id
  else
    call s:close_split_win()
  endif

  if exists('*lightline#update')
    call lightline#update()
  endif
endfunction

function! which_key#window#name() abort
  return get(s:, 'name', '')
endfunction
