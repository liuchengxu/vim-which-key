scriptencoding utf-8

let g:which_key#util#TYPE = {
      \ 'list':    type([]),
      \ 'dict':    type({}),
      \ 'number':  type(0),
      \ 'string':  type(''),
      \ 'funcref': type(function('call'))
      \ }

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

function! which_key#util#get_sep() abort
  return get(g:, 'which_key_sep', '→')
endfunction

function! which_key#util#string_to_keys(input)
  let input = a:input
  " Avoid special case: <>
  if match(input, '<.\+>') != -1
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

function! which_key#util#undefined(key) abort
  echohl ErrorMsg
  echom '[which-key] '.a:key.' is undefined'
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
