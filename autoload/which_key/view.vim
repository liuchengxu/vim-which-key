let s:TYPE = g:which_key#util#TYPE
let s:displaynames = {
      \ ' ': 'SPC',
      \ '<C-H>': 'BS',
      \ '<C-I>': 'TAB',
      \ '<TAB>': 'TAB',
      \ }

function! which_key#view#prepare(runtime) abort
  let layout = s:calc_layout(a:runtime)
  let rows = s:create_rows(layout, a:runtime)

  return [layout, rows]
endfunction

function! s:calc_layout(mappings) abort " {{{
  let layout = {}
  let smap = filter(copy(a:mappings), 'v:key !=# "name" && !(type(v:val) == s:TYPE.list && v:val[1] == "which_key_ignore")')
  let layout.n_items = len(smap)
  let length = values(map(smap,
        \ 'strdisplaywidth(get(s:displaynames, toupper(v:key), v:key).'.
        \ '(type(v:val) == s:TYPE.dict ? get(v:val, "name", "") : v:val[1]))'))

  let maxlength = max(length) + g:which_key_hspace
  if g:which_key_vertical
    let layout.n_rows = winheight(0) - 2
    let layout.n_cols = layout.n_items / layout.n_rows + (layout.n_items != layout.n_rows)
    let layout.col_width = maxlength
    let layout.win_dim = layout.n_cols * layout.col_width
  else
    let layout.n_cols = winwidth(0) / maxlength
    let layout.n_rows = layout.n_items / layout.n_cols + (fmod(layout.n_items,layout.n_cols) > 0 ? 1 : 0)
    let layout.col_width = winwidth(0) / layout.n_cols
    let layout.win_dim = layout.n_rows
  endif

  if g:which_key_max_size
    let layout.win_dim = min([g:which_key_max_size, layout.win_dim])
  endif

  return layout
endfunction " }}}

function! s:create_rows(layout, mappings) abort
  let l = a:layout
  let mappings = a:mappings

  let l.capacity = l.n_rows * l.n_cols
  let overcap = l.capacity - l.n_items
  let overh = l.n_cols - overcap
  let n_rows =  l.n_rows - 1

  let rows = []
  let row = 0
  let col = 0
  let smap = sort(filter(keys(mappings), 'v:val !=# "name"'),'1')

  if get(g:, 'which_key_align_by_seperator', 1)
    let key_max_len = 0
    for k in smap
      let key = get(s:displaynames, toupper(k), k)
      let width = strdisplaywidth(key)
      if width > key_max_len
        let key_max_len = width
      endif
    endfor
  endif

  for k in smap
    let key = get(s:displaynames, toupper(k), k)
    let desc = type(mappings[k]) == s:TYPE.dict ? get(mappings[k], "name", "") : mappings[k][1]
    if desc == 'which_key_ignore'
      continue
    endif

    if get(g:, 'which_key_align_by_seperator', 1)
      let width = strdisplaywidth(key)
      if key_max_len > width
        let key = repeat(' ', key_max_len - width).key
      endif
    endif

    let item = s:combine(key, desc)

    let crow = get(rows, row, [])
    if empty(crow)
      call add(rows, crow)
    endif
    call add(crow, item.repeat(' ', l.col_width - strdisplaywidth(item)))

    if !g:which_key_sort_horizontal
      if row >= n_rows - 1
        if overh > 0 && row < n_rows
          let overh -= 1
          let row += 1
        else
          let row = 0
          let col += 1
        endif
      else
        let row += 1
      endif
    else
      if col == l.n_cols - 1
        let row +=1
        let col = 0
      else
        let col += 1
      endif
    endif
    " This would cause bugs when using vim popup
    "silent execute "cnoremap <nowait> <buffer> ".substitute(k, "|", "<Bar>", ""). " " . s:escape_keys(k) ."<CR>"
  endfor

  call map(rows, 'join(v:val, "")')

  return rows
endfunction " }}}

function! s:combine(key, desc) abort
  return join([a:key, g:which_key_sep, a:desc], ' ')
endfunction

function! s:escape_keys(inp) abort " {{{
  " :h <>
  let l:ret = a:inp
  let l:ret = substitute(l:ret, "<", "<lt>", "")
  let l:ret = substitute(l:ret, "|", "<Bar>", "")
  return l:ret
endfunction " }}}
