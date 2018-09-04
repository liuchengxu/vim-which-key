let s:desc = get(s:, 'desc', {})
let s:cache = get(s:, 'cache', {})
let s:TYPE = {
      \ 'string':  type(''),
      \ 'list':    type([]),
      \ 'dict':    type({}),
      \ 'funcref': type(function('call'))
      \ }

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
    call s:start_parser(key, s:cache[key])
  endif

  let s:runtime = has_key(s:desc, key) || has_key(s:desc , 'top') ? s:create_target_dict(key) : s:cache[key]
  let s:which_key_trigger = key ==# ' ' ? 'SPC' : key

  call which_key#window#open(s:runtime)
endfunction

function! s:start_parser(key, dict) " {{{
  let key = a:key ==? ' ' ? "<Space>" : a:key
  let lines = s:get_raw_key_mapping(key)
  let visual = s:vis ==# "gv" ? 1 : 0

  for line in lines
    let mapd = maparg(split(line[3:])[0], line[0], 0, 1)
    if mapd.lhs =~? '<Plug>.*' || mapd.lhs =~? '<SNR>.*'
      continue
    endif

    let mapd.display = call(g:WhichKeyFormatFunc, [mapd.rhs])

    let mapd.lhs = substitute(mapd.lhs, key, '', '')
    " FIXME: <Plug>(easymotion-prefix)
    if mapd.lhs ==? '<Space>'
      continue
    endif

    let mapd.lhs = substitute(mapd.lhs, "<Space>", " ", "g")
    let mapd.lhs = substitute(mapd.lhs, "<Tab>", "<C-I>", "g")

    let mapd.rhs = substitute(mapd.rhs, "<SID>", "<SNR>".mapd['sid']."_", "g")

    if mapd.lhs != '' && mapd.display !~# 'WhichKey.*'
      if (visual && match(mapd.mode, "[vx ]") >= 0) ||
            \ (!visual && match(mapd.mode, "[vx]") == -1)
      let mapd.lhs = which_key#util#string_to_keys(mapd.lhs)
      call s:add_map_to_dict(mapd, 0, a:dict)
      endif
    endif
  endfor
endfunction

function! s:add_map_to_dict(map, level, dict) " {{{
  if len(a:map.lhs) > a:level+1
    let curkey = a:map.lhs[a:level]
    let nlevel = a:level+1

    if !has_key(a:dict, curkey)
      let a:dict[curkey] = { 'name' : g:which_key_default_group_name }
    " mapping defined already, flatten this map
    elseif type(a:dict[curkey]) == s:TYPE.list && g:which_key_flatten
      let cmd = which_key#util#escape_mappings(a:map)
      let curkey = join(a:map.lhs[a:level+0:], '')
      let nlevel = a:level
      if !has_key(a:dict, curkey)
        let a:dict[curkey] = [cmd, a:map.display]
      endif
    elseif type(a:dict[curkey]) == s:TYPE.list && g:which_key_flatten == 0
      let cmd = which_key#util#escape_mappings(a:map)
      let curkey = curkey."m"
      if !has_key(a:dict, curkey)
        let a:dict[curkey] = { 'name' : g:which_key_default_group_name }
      endif
    endif
    " next level
    if type(a:dict[curkey]) == s:TYPE.dict
      call s:add_map_to_dict(a:map, nlevel, a:dict[curkey])
    endif
  else
    let cmd = which_key#util#escape_mappings(a:map)
    if !has_key(a:dict, a:map.lhs[a:level])
      let a:dict[a:map.lhs[a:level]] = [cmd, a:map.display]
    " spot is taken already, flatten existing submaps
    elseif type(a:dict[a:map.lhs[a:level]]) == s:TYPE.dict && g:which_key_flatten
      let childmap = s:flattenmap(a:dict[a:map.lhs[a:level]], a:map.lhs[a:level])
      for it in keys(childmap)
        let a:dict[it] = childmap[it]
      endfor
      let a:dict[a:map.lhs[a:level]] = [cmd, a:map.display]
    endif
  endif
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
  call extend(target, other, 'keep')
endfunction

function! s:get_raw_key_mapping(key) abort
  let readmap = ''
  redir => readmap
  silent execute 'map' a:key
  redir END
  return split(readmap, "\n")
endfunction

function! s:flattenmap(dict, str) abort " {{{
  let ret = {}
  for kv in keys(a:dict)
    if type(a:dict[kv]) == s:TYPE.list
      let toret = {}
      let toret[a:str.kv] = a:dict[kv]
      return toret
    elseif type(a:dict[kv]) == s:TYPE.dict
      let strcall = a:str.kv
      call extend(ret, s:flattenmap(a:dict[kv], a:str.kv))
    endif
  endfor
  return ret
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
        call s:start_parser(k, v)
    endfor
endfunction " }}}
