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
  let s:count = v:count != 0 ? v:count : ''
  let s:which_key_trigger = ''

  if a:bang
    let s:runtime = a:prefix
    call which_key#window#open(s:runtime)
    return
  endif

  let key = a:prefix
  let s:which_key_trigger = key ==# ' ' ? '<space>' : key

  if !has_key(s:cache, key) || g:which_key_run_map_on_popup
    " First run
    let s:cache[key] = {}
    call which_key#map#parse(key, s:cache[key], s:vis ==# 'gv' ? 1 : 0)
  endif

  " s:runtime is a dictionary combining the native key mapping dictionary
  " parsed by vim-which-key itself with user defined prefix dictionary if avaliable.
  let s:runtime = s:create_runtime(key)

  if getchar(1)
    while 1
      try
        let c = getchar()
      catch /^Vim:Interrupt$/
        return ''
      endtry
      if s:is_exit_code(c)
        return ''
      endif
      let char = c == 9 ? '<Tab>' : nr2char(c)
      let s:which_key_trigger .= ' '.char
      let next_level = get(s:runtime, char)
      let ty = type(next_level)
      if ty == s:TYPE.dict
        let s:runtime = next_level
      elseif ty == s:TYPE.list
        call s:execute(next_level[0])
        return
      elseif g:which_key_fallback_to_native_key
        call s:execute_native_fallback()
        return
      else
        call which_key#util#undefined(s:which_key_trigger)
        return
      endif
      if s:wait_with_timeout(g:which_key_timeout)
        break
      endif
    endwhile
  endif

  let s:last_runtime_stack = [copy(s:runtime)]
  call which_key#window#open(s:runtime)
endfunction

" Argument: number
function! s:is_exit_code(raw_char) abort
  if !exists('s:exit_code')
    if exists('g:which_key_exit')
      let ty = type(g:which_key_exit)
      if ty == s:TYPE.number || ty == s:TYPE.string
        let s:exit_code = [g:which_key_exit]
      elseif ty == s:TYPE.list
        let s:exit_code = g:which_key_exit
      else
        echohl ErrorMsg
        echom '[which-key] '.a:raw_char.' is invalid for option g:which_key_exit'
        echohl None
        return 1
      endif
    else
      " <Esc>, <C-[>: 27
      let s:exit_code = [27]
    endif
  endif

  for e in s:exit_code
    let ty = type(e)
    if ty == s:TYPE.number && e == a:raw_char
      return 1
    elseif ty == s:TYPE.string && e == nr2char(a:raw_char)
      return 1
    endif
  endfor

  return 0
endfunction

function! s:create_runtime(key)
  let key = a:key
  if has_key(s:desc, key)
    let runtime = deepcopy({s:desc[key]})
    let native = s:cache[key]
    call s:merge(runtime, native)
  else
    let runtime = s:cache[key]
  endif
  return runtime
endfunction

function! s:merge(target, native) " {{{
  let target = a:target
  let native = a:native

  for [k, v] in items(target)

    if type(v) == s:TYPE.dict && has_key(native, k)

      if type(native[k]) == s:TYPE.dict
        if has_key(v, 'name')
          let native[k].name = v.name
        endif
        call s:merge(target[k], native[k])
      elseif type(native[k]) == s:TYPE.list
        let target[k] = native[k]
      endif

    " Support add a description to an existing map without dual definition
    elseif type(v) == s:TYPE.string && k != 'name'

      " <Tab> <C-I>
      if k == '<Tab>' && has_key(native, '<C-I>')
        let target[k] = [
              \ native['<C-I>'][0],
              \ v]
      else
        let target[k] = [
              \ has_key(native, k) ? native[k][0] : 'which_key#util#mismatch()',
              \ v]
      endif

    endif

  endfor

  " TODO handle <C-I>, <Tab> more clearly
  if has_key(native, '<C-I>')
    if !has_key(target, '<Tab>')
      let target['<Tab>'] = native['<C-I>']
    endif
    call remove(native, '<C-I>')
  endif

  call extend(target, native, 'keep')
endfunction

function! s:prompt() abort
  echohl Keyword
  echo s:which_key_trigger.'- '
  echohl None

  echohl String
  echon which_key#window#name()
  echohl None
endfunction

" Returns true if timed out
function! s:wait_with_timeout(timeout)
  let timeout = a:timeout
  while timeout >= 0
    if getchar(1)
      return 0
    endif
    if timeout > 0
      sleep 20m
    endif
    let timeout -= 20
  endwhile
  return 1
endfunction

function! s:has_children(input) abort
  let group = map(keys(s:runtime), 'v:val =~# "^'.a:input.'"')
  let group = filter(group, 'v:val == 1')
  return len(group) > 1
endfunction

function! s:getchar() abort
  let input = ''
  try
    let c = getchar()
  " Handle <C-C>
  catch /^Vim:Interrupt$/
    call which_key#window#close()
    redraw!
    return ''
  endtry

  if s:is_exit_code(c)
    call which_key#window#close()
    redraw!
    return ''
  endif

  " Allow <BS> to go back to the upper level.
  if c == "\<BS>"
    " Top level
    if empty(s:last_runtime_stack)
      call which_key#window#show(s:runtime)
      return ''
    endif

    let last_runtime = s:last_runtime_stack[-1]
    let s:runtime = last_runtime

    if len(s:last_runtime_stack) > 1
      let s:which_key_trigger = join(split(s:which_key_trigger)[:-2], ' ')
    endif

    unlet s:last_runtime_stack[-1]

    call which_key#window#show(last_runtime)
    return ''
  endif

  let input .= which_key#util#parse_getchar(c)
  if s:has_children(input)
    while 1
      if !s:wait_with_timeout(g:which_key_timeout)
        let input .= which_key#util#parse_getchar(getchar())
      else
        break
      endif
    endwhile
  endif

  return input
endfunction

function! which_key#wait_for_input() " {{{
  " redraw is needed!
  redraw

  " Append the prompt in the buffer at last when using floating or
  " popup wnidow, otherwise show it in the cmdline.
  if !g:which_key_use_floating_win
    call s:prompt()
  endif

  let char = s:getchar()
  if char ==# ''
    return
  endif

  let s:cur_char = char

  call s:handle_input(get(s:runtime, char))
endfunction

function! s:handle_input(input) " {{{
  let ty = type(a:input)

  if ty ==? s:TYPE.dict
    let s:which_key_trigger .= ' '. (s:cur_char ==# ' ' ? '<space>' : s:cur_char)
    call add(s:last_runtime_stack, copy(s:runtime))
    let s:runtime = a:input
    call which_key#window#show(s:runtime)
    return
  endif

  if ty ==? s:TYPE.list
    call which_key#window#close()
    call s:execute(a:input[0])
  elseif g:which_key_fallback_to_native_key
    call which_key#window#close()
    " Is redraw needed here?
    " redraw!
    call s:execute_native_fallback()
  else
    if g:which_key_ignore_invalid_key
      call which_key#wait_for_input()
    else
      call which_key#window#close()
      redraw!
      call which_key#util#undefined(s:which_key_trigger)
    endif
  endif
endfunction

function! s:execute_native_fallback() abort
  let l:reg = which_key#util#get_register()
  let l:fallback_cmd = s:vis.l:reg.s:count.substitute(s:which_key_trigger, ' ', '', '').get(s:, 'cur_char', '')
  try
    execute 'normal! '.l:fallback_cmd
  catch
    echohl ErrorMsg
    echom '[which-key] Exception: '.v:exception.' occurs for the fallback mapping: '.l:fallback_cmd
    echohl None
  endtry
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
    elseif Cmd =~? '.(*)$' && match(Cmd, '\<call\>') == -1
      let Cmd = s:join('call', Cmd)
    elseif exists(':'.Cmd)  || Cmd =~ '^:' || Cmd =~? '^call feedkeys(.*)$'
      let Cmd = Cmd
    else
      let Cmd = s:join('call', 'feedkeys("'.Cmd.'")')
    endif
    execute Cmd
  catch
    echom v:exception
  endtry
endfunction

function! which_key#trigger() abort
  return get(s:, 'which_key_trigger', '')
endfunction

function! which_key#statusline() abort
  let key = '%#WhichKeyTrigger# %{get(s:, "which_key_trigger", "")} %*'
  let name = '%#WhichKeyName# %{which_key#window#name()} %*'
  return key.name
endfunction

" Update the cache manually by calling this function.
function! which_key#parse_mappings() " {{{
    for [k, v] in items(s:cache)
      call which_key#map#parse(k, v, s:vis ==# 'gv' ? 1 : 0)
    endfor
endfunction " }}}
