let s:desc = get(s:, 'desc', {})
let s:cache = get(s:, 'cache', {})
let s:TYPE = g:which_key#util#TYPE

function! which_key#register(prefix, dict) abort
  let key = a:prefix ==? '<Space>' ? ' ' : a:prefix
  let val = a:dict
  call extend(s:desc, {key:val})
endfunction

function! which_key#start(vis, bang, prefix) " {{{
  let s:vis = a:vis ? 'gv' : ''
  if a:bang
    let s:runtime = a:prefix
    call which_key#window#open(s:runtime)
    return
  endif

  let s:count = v:count != 0 ? v:count : ''
  let s:toplevel = a:prefix ==# 'top' ? 1 : 0

  let key = a:prefix
  let s:cur_trigger = a:prefix

  if !has_key(s:cache, key) || g:which_key_run_map_on_popup
    " First run
    let s:cache[key] = {}
    call which_key#map#parse(key, s:cache[key], s:vis ==# 'gv' ? 1 : 0)
  endif

  let s:runtime = has_key(s:desc, key) || has_key(s:desc , 'top') ? s:create_target_dict(key) : s:cache[key]
  let s:which_key_trigger = key ==# ' ' ? 'SPC' : key

  call which_key#window#open(s:runtime)
endfunction

function! s:create_target_dict(key) " {{{
  if has_key(s:desc, 'top')
    let toplevel = deepcopy({s:desc['top']})
    let tardict = s:toplevel ? toplevel : get(toplevel, a:key, {})
    let mapdict = s:cache[a:key]
    call s:merge(tardict, mapdict)
  elseif has_key(s:desc, a:key)
    let tardict = deepcopy({s:desc[a:key]})
    let mapdict = s:cache[a:key]
    call s:merge(tardict, mapdict)
  else
    let tardict = s:cache[a:key]
  endif
  return tardict
endfunction

function! s:merge(dict_t, dict_o) " {{{
  let target = a:dict_t
  let other = a:dict_o
  for k in keys(target)
    if type(target[k]) == s:TYPE.dict && has_key(other, k)
      if type(other[k]) == type({})
        if has_key(target[k], 'name')
          let other[k].name = target[k].name
        endif
        call s:merge(target[k], other[k])
      elseif type(other[k]) == s:TYPE.list
        if g:which_key_flatten == 0 || type(target[k]) == s:TYPE.dict
          let target[k.'m'] = target[k]
        endif
        let target[k] = other[k]
        if has_key(other, k.'m') && type(other[k.'m']) == s:TYPE.dict
          call s:merge(target[k.'m'], other[k.'m'])
        endif
      endif
    endif
  endfor

  for [key, value] in items(target)
    if key == 'name'
      continue
    endif
    if type(value) == s:TYPE.string
      if key == '<Tab>' && has_key(other, '<C-I>')
        let target[key] = [other['<C-I>'][0], value]
      else
        let target[key] = [
              \ has_key(other, key) ? other[key][0] : 'which_key#util#mismatch()',
            \ value ]
      endif
    endif
  endfor

  if has_key(other, '<C-I>')
    if !has_key(target, '<Tab>')
      let target['<Tab>'] = other['<C-I>']
    endif
    call remove(other, '<C-I>')
  endif

  call extend(target, other, 'keep')
endfunction

function! s:prompt() abort
  redraw
  echohl Keyword
  echo s:which_key_trigger.'- '
  echohl None

  echohl String
  echon which_key#window#name()
  echohl None
endfunction

function! s:getchar() abort
  try
    let c = getchar()
  " Handle <C-C>
  catch /^Vim:Interrupt$/
    let c = 27
  endtry

  " <Esc>, <C-[>: 27
  if c == 27
    call which_key#window#close()
    redraw!
    return ''
  endif

  " <Tab>, <C-I>
  if c == 9
    return '<Tab>'
  endif

  if c =~? '^\d\+$' || type(c) == type(0)
    return nr2char(c)
  else
    return ''
  endif
endfunction

function! which_key#wait_for_input() " {{{
  call s:prompt()

  let char = s:getchar()
  if char ==# ''
    return
  endif

  let s:which_key_trigger .= ' '. (char ==# ' ' ? 'SPC' : char)

  call s:handle_input(get(s:runtime, char))
endfunction

function! s:handle_input(input) " {{{
  call which_key#window#close()

  let type = type(a:input)

  if type ==? s:TYPE.dict
    let s:runtime = a:input
    call which_key#window#open(s:runtime)
  elseif type ==? s:TYPE.list
    call s:execute(a:input[0])
  else
    redraw!
    echohl ErrorMsg
    echom s:which_key_trigger.' is undefined'
    echohl None
  endif
endfunction

function! s:join(...) abort
  return join(a:000, ' ')
endfunction

function! s:execute(cmd) abort
  let reg = which_key#util#get_register()
  if s:vis.reg.s:count !=# ''
    execute 'normal!' s:vis.reg.s:count
  endif
  redraw
  let Cmd = a:cmd
  try
    if type(Cmd) == s:TYPE.funcref
      call call(Cmd, [])
      return
    endif
    if Cmd =~? '^<Plug>.\+' || Cmd =~? '^<C-W>.\+' || Cmd =~? '^<.\+>$'
      let Cmd = s:join('call', 'feedkeys("\'.Cmd.'")')
    elseif Cmd =~? '.(*)$' && match(Cmd, 'call') == -1
      let Cmd = s:join('call', Cmd)
    endif
    execute Cmd
  catch
    echom v:exception
  endtry
endfunction

function! which_key#statusline() abort
  let key = '%#WhichKeyTrigger# %{s:which_key_trigger} %*'
  let name = '%#WhichKeyName# %{which_key#window#name()} %*'
  return key.name
endfunction

" Update the cache manually by calling this function.
function! which_key#parse_mappings() " {{{
    for [k, v] in items(s:cache)
      call which_key#map#parse(k, v, s:vis ==# 'gv' ? 1 : 0)
    endfor
endfunction " }}}
