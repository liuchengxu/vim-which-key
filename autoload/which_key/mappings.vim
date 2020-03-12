let s:TYPE = g:which_key#TYPE

function! s:string_to_keys(input) abort
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

function! s:get_raw_map_info(key) abort
  return split(execute('map '.a:key), "\n")
endfunction

" Parse key-mappings gathered by `:map` and feed them into dict
function! which_key#mappings#parse(key, dict, visual) " {{{
  let key = a:key ==? ' ' ? '<Space>' : a:key
  let visual = a:visual

  let lines = s:get_raw_map_info(key)

  for line in lines
    let mapd = maparg(split(line[3:])[0], line[0], 0, 1)
    if empty(mapd) || mapd.lhs =~? '<Plug>.*' || mapd.lhs =~? '<SNR>.*'
      continue
    endif

    let mapd.display = call(g:WhichKeyFormatFunc, [mapd.rhs])

    let mapd.lhs = substitute(mapd.lhs, key, '', '')
    " FIXME: <Plug>(easymotion-prefix)
    if mapd.lhs ==? '<Space>'
      continue
    endif

    let mapd.lhs = substitute(mapd.lhs, '<Space>', ' ', 'g')
    let mapd.lhs = substitute(mapd.lhs, '<Tab>', '<C-I>', 'g')

    let mapd.rhs = substitute(mapd.rhs, '<SID>', '<SNR>'.mapd['sid'].'_', 'g')

    " eval the expression as the final {rhs}
    " Ref #60
    if mapd.expr
      let mapd.rhs = eval(mapd.rhs)
    endif

    if mapd.lhs !=# '' && mapd.display !~# 'WhichKey.*'
      if (visual && match(mapd.mode, '[vx ]') >= 0) ||
            \ (!visual && match(mapd.mode, '[vx]') == -1)
        let mapd.lhs = s:string_to_keys(mapd.lhs)
        call s:add_map_to_dict(mapd, 0, a:dict)
      endif
    endif
  endfor
endfunction

function! s:escape(mapping) abort " {{{
  let feedkeyargs = a:mapping.noremap ? 'nt' : 'mt'
  let rhs = substitute(a:mapping.rhs, '\', '\\\\', 'g')
  let rhs = substitute(rhs, '<\([^<>]*\)>', '\\<\1>', 'g')
  let rhs = substitute(rhs, '"', '\\"', 'g')
  let rhs = 'call feedkeys("'.rhs.'", "'.feedkeyargs.'")'
  return rhs
endfunction " }}}

function! s:add_map_to_dict(map, level, dict) " {{{

  let cmd = s:escape(a:map)

  if len(a:map.lhs) > a:level+1
    let curkey = a:map.lhs[a:level]
    let nlevel = a:level+1

    if !has_key(a:dict, curkey)
      let a:dict[curkey] = { 'name' : g:which_key_default_group_name }
    " mapping defined already, flatten this map
    elseif type(a:dict[curkey]) == s:TYPE.list

      if g:which_key_flatten
        let curkey = join(a:map.lhs[a:level+0:], '')
        let nlevel = a:level
        if !has_key(a:dict, curkey)
          let a:dict[curkey] = [cmd, a:map.display]
        endif
      else
        let curkey = curkey.'m'
        if !has_key(a:dict, curkey)
          let a:dict[curkey] = { 'name' : g:which_key_default_group_name }
        endif
      endif
    endif
    " next level
    if type(a:dict[curkey]) == s:TYPE.dict
      call s:add_map_to_dict(a:map, nlevel, a:dict[curkey])
    endif

  else

    let lhs_at_level = a:map.lhs[a:level]

    if !has_key(a:dict, lhs_at_level)
      let a:dict[lhs_at_level] = [cmd, a:map.display]
    " spot is taken already, flatten existing submaps
    elseif type(a:dict[lhs_at_level]) == s:TYPE.dict
          \ && g:which_key_flatten
      let childmap = s:flatten(a:dict[lhs_at_level], lhs_at_level)
      for it in keys(childmap)
        let a:dict[it] = childmap[it]
      endfor
      let a:dict[lhs_at_level] = [cmd, a:map.display]
    endif

  endif
endfunction

" Flatten map
function! s:flatten(dict, str) abort
  let flat = {}
  for kv in keys(a:dict)
    let ty = type(a:dict[kv])
    if ty == s:TYPE.list
      let toret = {}
      let toret[a:str.kv] = a:dict[kv]
      return toret
    elseif ty == s:TYPE.dict
      call extend(flat, s:flatten(a:dict[kv], a:str.kv))
    endif
  endfor
  return flat
endfunction
