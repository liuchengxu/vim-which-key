scriptencoding utf-8

let g:which_key#util#TYPE = {
      \ 'string':  type(''),
      \ 'list':    type([]),
      \ 'dict':    type({}),
      \ 'funcref': type(function('call'))
      \ }

let s:displaynames = {
      \ ' ': 'SPC',
      \ '<C-H>': 'BS',
      \ '<C-I>': 'TAB',
      \ '<TAB>': 'TAB',
      \ }

function! which_key#util#calc_layout(mappings) abort " {{{
  let layout = {}
  let smap = filter(copy(a:mappings), 'v:key !=# "name" && !(type(v:val) == type([]) && v:val[1] == "which_key_ignore")')
  let layout.n_items = len(smap)
  let length = values(map(smap,
        \ 'strdisplaywidth(get(s:displaynames, toupper(v:key), v:key).'.
        \ '(type(v:val) == type({}) ? v:val["name"] : v:val[1]))'))

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

function! which_key#util#create_rows(layout, mappings) abort
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

  for k in smap
    let key = get(s:displaynames, toupper(k), k)
    let desc = type(mappings[k]) == type({}) ? mappings[k].name : mappings[k][1]
    if desc == 'which_key_ignore'
      continue
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
    silent execute "cnoremap <nowait> <buffer> ".substitute(k, "|", "<Bar>", ""). " " . s:escape_keys(k) ."<CR>"
  endfor

  if get(g:, 'which_key_align_by_seperator', 1)
    for i in range(0, col-1)
      let cur_col = []
      for j in range(0, n_rows)
        if i < len(rows[j])
          call add(cur_col, rows[j][i])
        endif
      endfor
      let cur_col_keys = map(cur_col, 'strdisplaywidth(split(v:val)[0])')
      let [max_key_len, min_key_len] = [max(cur_col_keys), min(cur_col_keys)]
      if max_key_len != min_key_len
        for j in range(0, n_rows)
          if i < len(rows[j])
            let key = split(rows[j][i])[0]
            let len = strdisplaywidth(key)
            let rows[j][i] = repeat(' ', max_key_len-len).rows[j][i][0:(l.col_width + 1 - (max_key_len -len))]
          endif
        endfor
      endif
    endfor
  endif

  call map(rows, 'join(v:val, "")')

  return rows
endfunction " }}}

function! s:escape_keys(inp) abort " {{{
  " :h <>
  let l:ret = a:inp
  let l:ret = substitute(l:ret, "<", "<lt>", "")
  let l:ret = substitute(l:ret, "|", "<Bar>", "")
  return l:ret
endfunction " }}}

function! s:combine(key, desc) abort
  return join([a:key, g:which_key_sep, a:desc], ' ')
endfunction

function! s:register() abort
  let clipboard = &clipboard
  if clipboard ==# 'unnamedplus'
    return '+'
  elseif clipboard ==# 'unnamed'
    return '*'
  else
    return '"'
  endif
endfunction

function! which_key#util#get_register() "{{{
 if has('nvim') && !exists('s:reg')
    let s:reg = ''
  else
    let s:reg = v:register != s:register() ? '"'.v:register : ''
  endif
  return s:reg
endfunction "}}}

function! which_key#util#escape_mappings(mapping) abort " {{{
  let feedkeyargs = a:mapping.noremap ? "nt" : "mt"
  let rhs = substitute(a:mapping.rhs, '\', '\\\\', 'g')
  let rhs = substitute(rhs, '<\([^<>]*\)>', '\\<\1>', 'g')
  let rhs = substitute(rhs, '"', '\\"', 'g')
  let rhs = 'call feedkeys("'.rhs.'", "'.feedkeyargs.'")'
  return rhs
endfunction " }}}

function! which_key#util#get_sep() abort
  return get(g:, 'which_key_sep', '→')
endfunction

function! which_key#util#string_to_keys(input)
  let input = a:input
  " Avoid special case: <>
  if match(input, '<.\+>') != -1
    echom "match input: ".input
    let retlist = []
    let si = 0
    let go = 1
    while si < len(input)
      if go
        call add(retlist, input[si])
      else
        let retlist[-1] .= input[si]
      endif
      if input[si] ==? '<'
        let go = 0
      elseif input[si] ==? '>'
        let go = 1
      end
      let si += 1
    endwhile
    return retlist
  else
    return split(input, '\zs')
  endif
endfunction " }}}

function! which_key#util#mismatch() abort
  echohl ErrorMsg
  echom '[which-key] Fail to execute, no such mapping'
  echohl None
endfunction

function! which_key#util#format(mapping) abort
  let l:ret = a:mapping
  let l:ret = substitute(l:ret, '\c<cr>$', '', '')
  let l:ret = substitute(l:ret, '^:', '', '')
  let l:ret = substitute(l:ret, '^\c<c-u>', '', '')
  " let l:ret = substitute(l:ret, '^<Plug>', '', '')
  return l:ret
endfunction
