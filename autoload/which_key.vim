scriptencoding utf-8

let s:desc = get(s:, 'desc', {})
let s:cache = get(s:, 'cache', {})
let s:TYPE = {
      \ 'list':    type([]),
      \ 'dict':    type({}),
      \ 'number':  type(0),
      \ 'string':  type(''),
      \ 'funcref': type(function('call'))
      \ }
let g:which_key#TYPE = s:TYPE

let s:should_note_winid = exists('*win_getid')

function! which_key#register(prefix, dict) abort
  let key = a:prefix ==? '<Space>' ? ' ' : a:prefix
  let val = a:dict
  call extend(s:desc, {key:val})
endfunction

" No need to open which-key window, execute the acction according to the current input.
function! s:handle_char_on_start_is_ok(c) abort
  if which_key#char_handler#is_exit_code(a:c)
    return 1
  endif
  let char = a:c == 9 ? '<Tab>' : nr2char(a:c)
  let s:which_key_trigger .= ' '.char
  let next_level = get(s:runtime, char)
  let ty = type(next_level)
  if ty == s:TYPE.dict
    let s:runtime = next_level
    return 0
  elseif ty == s:TYPE.list
    call s:execute(next_level[0])
    return 1
  elseif g:which_key_fallback_to_native_key
    call s:execute_native_fallback()
    return 1
  else
    call which_key#error#undefined_key(s:which_key_trigger)
    return 1
  endif
endfunction

function! which_key#start(vis, bang, prefix) " {{{
  let s:vis = a:vis ? 'gv' : ''
  let s:count = v:count != 0 ? v:count : ''
  let s:which_key_trigger = ''

  if s:should_note_winid
    let g:which_key_origin_winid = win_getid()
  endif

  if a:bang
    let s:runtime = a:prefix
    let s:last_runtime_stack = [copy(s:runtime)]
    call which_key#window#show(s:runtime)
    return
  endif

  let key = a:prefix
  let s:which_key_trigger = key ==# ' ' ? '<space>' : key

  if !has_key(s:cache, key) || g:which_key_run_map_on_popup
    " First run
    let s:cache[key] = {}
    call which_key#mappings#parse(key, s:cache[key], s:vis ==# 'gv' ? 1 : 0)
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
      if s:handle_char_on_start_is_ok(c)
        return
      endif
      " When there are next level options, wait another timeoutlen.
      " https://github.com/liuchengxu/vim-which-key/issues/3
      " https://github.com/liuchengxu/vim-which-key/issues/4
      if which_key#char_handler#wait_with_timeout()
        break
      endif
    endwhile
  endif

  let s:last_runtime_stack = [copy(s:runtime)]
  call which_key#window#show(s:runtime)
endfunction

function! s:create_runtime(key)
  let key = a:key
  if has_key(s:desc, key)
    if type(s:desc[key]) == s:TYPE.dict
      let runtime = deepcopy(s:desc[key])
    else
      let runtime = deepcopy({s:desc[key]})
    endif
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
    elseif type(v) == s:TYPE.string && k !=# 'name'

      " <Tab> <C-I>
      if k ==# '<Tab>' && has_key(native, '<C-I>')
        let target[k] = [
              \ native['<C-I>'][0],
              \ v]
      else
        let target[k] = [
              \ has_key(native, k) ? native[k][0] : 'which_key#error#missing_mapping()',
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

function! s:echo_prompt() abort
  echohl Keyword
  echo s:which_key_trigger.'- '
  echohl None

  echohl String
  echon which_key#window#name()
  echohl None
endfunction

function! s:has_children(input) abort
  " TODO: escape properly, E114: Missing quote: "^\"
  if a:input ==# '\'
    let group = map(keys(s:runtime), 'v:val =~# "^\'.a:input.'"')
  elseif a:input ==# '"'
    let group = map(keys(s:runtime), "v:val =~# '^".a:input."'")
  else
    let group = map(keys(s:runtime), 'v:val =~# "^'.a:input.'"')
  endif
  return len(filter(group, 'v:val == 1')) > 1
endfunction

function! s:show_upper_level_mappings() abort
  " Top level
  if empty(s:last_runtime_stack)
    call which_key#window#show(s:runtime)
    return
  endif

  let last_runtime = s:last_runtime_stack[-1]
  let s:runtime = last_runtime

  if len(s:last_runtime_stack) > 1
    let s:which_key_trigger = join(split(s:which_key_trigger)[:-2], ' ')
  endif

  unlet s:last_runtime_stack[-1]

  call which_key#window#show(last_runtime)
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

  if which_key#char_handler#is_exit_code(c)
    call which_key#window#close()
    redraw!
    return ''
  endif

  " Allow <BS> to go back to the upper level.
  if c ==# "\<BS>"
    call s:show_upper_level_mappings()
    return ''
  endif

  " :h keycode
  " <CR>, <Enter>
  if c == 13
    return '<CR>'
  endif

  let input .= which_key#char_handler#parse_raw(c)
  if s:has_children(input)
    while 1
      if !which_key#char_handler#timeout_for_next_char()
        let input .= which_key#char_handler#parse_raw(getchar())
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
    call s:echo_prompt()
  endif

  let char = s:getchar()
  if char ==# ''
    return
  endif

  let s:cur_char = char

  call s:handle_input(get(s:runtime, char))
endfunction

function! s:show_next_level_mappings(next_runtime) abort
  let s:which_key_trigger .= ' '. (s:cur_char ==# ' ' ? '<space>' : s:cur_char)
  call add(s:last_runtime_stack, copy(s:runtime))
  let s:runtime = a:next_runtime
  call which_key#window#show(s:runtime)
endfunction

function! s:handle_input(input) " {{{
  let ty = type(a:input)

  if ty ==? s:TYPE.dict
    call s:show_next_level_mappings(a:input)
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
      call which_key#error#undefined_key(s:which_key_trigger)
    endif
  endif
endfunction

function! s:execute_native_fallback() abort
  let l:reg = s:get_register()
  let l:fallback_cmd = s:vis.l:reg.s:count.substitute(s:which_key_trigger, ' ', '', '').get(s:, 'cur_char', '')
  try
    execute 'normal! '.l:fallback_cmd
  catch
    call which_key#error#report('Exception: '.v:exception.' occurs for the fallback mapping: '.l:fallback_cmd)
  endtry
endfunction

function! s:join(...) abort
  return join(a:000, ' ')
endfunction

function! s:execute(cmd) abort
  let reg = s:get_register()
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
    elseif exists(':'.Cmd)  || Cmd =~# '^:' || Cmd =~? '^call feedkeys(.*)$'
      let Cmd = Cmd
    else
      let Cmd = s:join('call', 'feedkeys("'.Cmd.'")')
    endif
    execute Cmd
  catch
    echom v:exception
  endtry
endfunction

" --------------------------------------
" Misc
" --------------------------------------
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

function! s:get_register() abort
 if has('nvim') && !exists('s:reg')
    let s:reg = ''
  else
    let s:reg = v:register != s:register() ? '"'.v:register : ''
  endif
  return s:reg
endfunction

" Update the cache manually by calling this function.
function! which_key#parse_mappings() " {{{
  for [k, v] in items(s:cache)
    call which_key#mappings#parse(k, v, s:vis ==# 'gv' ? 1 : 0)
  endfor
endfunction " }}}

function! which_key#format(mapping) abort
  let l:ret = a:mapping
  let l:ret = substitute(l:ret, '\c<cr>$', '', '')
  let l:ret = substitute(l:ret, '^:', '', '')
  let l:ret = substitute(l:ret, '^\c<c-u>', '', '')
  " let l:ret = substitute(l:ret, '^<Plug>', '', '')
  return l:ret
endfunction

function! which_key#statusline() abort
  let key = '%#WhichKeyTrigger# %{get(s:, "which_key_trigger", "")} %*'
  let name = '%#WhichKeyName# %{which_key#window#name()} %*'
  return key.name
endfunction

function! which_key#trigger() abort
  return get(s:, 'which_key_trigger', '')
endfunction

function! which_key#get_sep() abort
  return get(g:, 'which_key_sep', '→')
endfunction
