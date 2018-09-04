scriptencoding utf-8

let s:displaynames = {
      \ ' ': 'SPC',
      \ '<C-H>': '<BS>',
      \ '<C-I>': '<Tab>',
      \ }

function! which_key#util#calc_layout(mappings) abort
  let layout = {}
  let smap = filter(copy(a:mappings), 'v:key !=# "name"')
  let layout.n_items = len(smap)
  let length = values(map(smap,
        \ 'strdisplaywidth(v:key.'.
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

function! which_key#util#create_string(layout, mappings) abort
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
    let item = s:combine(key, desc)

    let crow = get(rows, row, [])
    if empty(crow)
      call add(rows, crow)
    endif
    call add(crow, item)
    call add(crow, repeat(' ', l.col_width - strdisplaywidth(item)))

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

  let r = []
  let mlen = 0
  for ro in rows
    let line = join(ro, '')
    call add(r, line)
    if strdisplaywidth(line) > mlen
      let mlen = strdisplaywidth(line)
    endif
  endfor

  call insert(r, '')
  let output = join(r, "\n ")

  return output
endfunction " }}}

function! s:escape_keys(inp) abort
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

function! which_key#util#escape_mappings(mapping) abort" {{{
  let feedkeyargs = a:mapping.noremap ? "nt" : "mt"
  let rstring = substitute(a:mapping.rhs, '\', '\\\\', 'g')
  let rstring = substitute(rstring, '<\([^<>]*\)>', '\\<\1>', 'g')
  let rstring = substitute(rstring, '"', '\\"', 'g')
  let rstring = 'call feedkeys("'.rstring.'", "'.feedkeyargs.'")'
  return rstring
endfunction " }}}

function! which_key#util#get_sep() abort
  return get(g:, 'which_key_sep', '→')
endfunction

function! which_key#util#string_to_keys(input)
  " Avoid special case: <>
  if match(a:input, '<.\+>') != -1
    let retlist = []
    let si = 0
    let go = 1
    while si < len(a:input)
      if go
        call add(retlist, a:input[si])
      else
        let retlist[-1] .= a:input[si]
      endif
      if a:input[si] ==? '<'
        let go = 0
      elseif a:input[si] ==? '>'
        let go = 1
      end
      let si += 1
    endw
    return retlist
  else
    return split(a:input, '\zs')
  endif
endfunction " }}}

function! which_key#util#format(mapping) abort
  let l:ret = a:mapping
  let l:ret = substitute(l:ret, '\c<cr>$', '', '')
  let l:ret = substitute(l:ret, '^:', '', '')
  let l:ret = substitute(l:ret, '^\c<c-u>', '', '')
  " let l:ret = substitute(l:ret, '^<Plug>', '', '')
  return l:ret
endfunction
