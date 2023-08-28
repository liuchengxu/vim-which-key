scriptencoding utf-8

let s:desc = get(s:, 'desc', { 'n': {}, 'v': {} })
let s:cache = get(s:, 'cache', { 'n': {}, 'v': {} })
let s:TYPE = {
      \ 'list':    type([]),
      \ 'dict':    type({}),
      \ 'number':  type(0),
      \ 'string':  type(''),
      \ 'funcref': type(function('call'))
      \ }
" For the purpose of mapping a keypress to internal data-structures
let s:KEYCODES = {
      \ "\<BS>": '<BS>',
      \ "\<Tab>": '<Tab>',
      \ "\<CR>": '<CR>',
      \ "\<Esc>": '<Esc>',
      \ "\<Del>": '<Del>'
      \ }
" For the purposes of merging identical keycodes in internal data-structures
let s:MERGE_INTO = {
      \ '<Space>': ' ',
      \ '<C-H>': '<BS>',
      \ '<C-I>': '<Tab>',
      \ '<C-M>': '<CR>',
      \ '<Return>': '<CR>',
      \ '<Enter>': '<CR>',
      \ '<C-[>': '<Esc>',
      \ '<lt>': '<',
      \ '<Bslash>': '\',
      \ '<Bar>': '|'
      \ }
let s:REQUIRES_REGEX_ESCAPE = ['$', '*', '~', '.']

let g:which_key#TYPE = s:TYPE

let s:should_note_winid = exists('*win_getid')

function! which_key#register(prefix, dict, ...) abort
  let key = has_key(s:MERGE_INTO, a:prefix) ?
    \ s:MERGE_INTO[a:prefix] : a:prefix
  let val = a:dict
  if a:0 == 1
    call extend(s:desc[a:1], {key:val})
  else
    call extend(s:desc['n'], {key:val})
    call extend(s:desc['v'], {key:val})
  endif
endfunction

" No need to open which-key window, execute the acction according to the current input.
function! s:handle_char_on_start_is_ok(c) abort
  if which_key#char_handler#is_exit_code(a:c)
    return 1
  endif
  let char = type(a:c) == s:TYPE.number ? nr2char(a:c) : a:c
  if has_key(s:KEYCODES, char)
    let char = s:KEYCODES[char]
  else
    let char = which_key#char_handler#parse_raw(char)
  endif
  let s:which_key_trigger .= ' '.(char ==# ' ' ? '<Space>' : char)
  let next_level = get(s:runtime, char)
  let ty = type(next_level)
  if ty == s:TYPE.dict
    let s:runtime = next_level
    return 0
  elseif ty == s:TYPE.list && (!g:which_key_fallback_to_native_key ||
    \ g:which_key_fallback_to_native_key &&
    \ next_level[0] !=# 'which_key#error#missing_mapping()')
    call s:execute(next_level[0])
    return 1
  elseif g:which_key_fallback_to_native_key
    call s:execute_native_fallback(0)
    return 1
  else
    call which_key#error#undefined_key(s:which_key_trigger)
    return 1
  endif
endfunction

function! which_key#start(vis, bang, prefix) " {{{
  let s:vis = a:vis ? 'gv' : ''
  let mode = a:vis ? 'v' : 'n'
  let prefix = a:prefix
  let s:count = v:count != 0 ? v:count : ''
  let s:which_key_trigger = ''

  if s:should_note_winid
    let g:which_key_origin_winid = win_getid()
  endif

  if a:bang
    for kv in keys(prefix)
      call s:cache_key(mode, kv)
    endfor
    let s:runtime = deepcopy(prefix)
    call s:merge(s:runtime, s:cache[mode])
  else
    if has_key(s:KEYCODES, prefix)
      let prefix = s:KEYCODES[prefix]
    else
      let prefix = which_key#char_handler#parse_raw(prefix)
    endif
    if has_key(s:MERGE_INTO, prefix)
      let prefix = s:MERGE_INTO[prefix]
    endif
    let key = prefix
    let s:which_key_trigger = key ==# ' ' ? '<Space>' : key
    call s:cache_key(mode, key)

    " s:runtime is a dictionary combining the native key mapping dictionary
    " parsed by vim-which-key itself with user defined prefix dictionary if avaliable.
    let s:runtime = s:create_runtime(mode, key)

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
  endif

  let s:last_runtime_stack = [copy(s:runtime)]
  call which_key#window#show(s:runtime)
endfunction

function! s:cache_key(mode, key)
  let mode = a:mode
  let key = a:key
  if !has_key(s:cache[mode], key) || g:which_key_run_map_on_popup
    let s:cache[mode][key] = {}
    call which_key#mappings#parse(key, s:cache[mode], mode)
  endif
endfunction

function! s:create_runtime(mode, key)
  let mode = a:mode
  let key = a:key
  if has_key(s:desc[mode], key)
    if type(s:desc[mode][key]) == s:TYPE.dict
      let runtime = deepcopy(s:desc[mode][key])
    else
      let runtime = deepcopy({s:desc[mode][key]})
    endif
    let native = s:cache[mode][key]
    call s:merge(runtime, native)
  else
    let runtime = s:cache[mode][key]
  endif
  return runtime
endfunction

function! s:merge(target, native) " {{{
  let target = a:target
  let native = a:native
  " e.g. <C-І> is merged into <Tab>, '<Space>' is merged into ' '
  call map(target, {k,v ->
  \ has_key(s:MERGE_INTO, k) ?
  \   (has_key(target, s:MERGE_INTO[k]) ?
  \     extend(target[s:MERGE_INTO[k]], target[k], 'keep') :
  \     extend(target, {s:MERGE_INTO[k]: target[k]})) :
  \   v})
  call filter(target, {k,_ -> !has_key(s:MERGE_INTO, k)})
  for [k, V] in items(target)
    " Support a `Dictionary-function` for on-the-fly mappings
    while type(target[k]) == s:TYPE.funcref
      " Evaluate the funcref, to allow the result to be processed
      let target[k] = target[k]()
    endwhile

    if type(V) == s:TYPE.dict
      if has_key(native, k)
        if type(native[k]) == s:TYPE.dict
          if has_key(V, 'name')
            let native[k].name = V.name
          endif
          call s:merge(target[k], native[k])
        elseif type(native[k]) == s:TYPE.list
          let target[k] = native[k]
        endif
      else
        " Process leaf nodes
        call s:merge(target[k], {})
      endif
    " Support add a description to an existing map without dual definition
    elseif type(V) == s:TYPE.string && k !=# 'name'
      if has_key(native, k)
        let target[k] = [native[k][0], V]
      else
        let target[k] = ['which_key#error#missing_mapping()', V]
      endif
    endif
  endfor

  if !g:which_key_ignore_outside_mappings
    call extend(target, native, 'keep')
  endif
endfunction

function! s:echo_prompt() abort
  echohl Keyword
  echo s:which_key_trigger.'- '
  echohl None

  echohl String
  echon which_key#window#name()
  echohl None
endfunction

if has('lambda')
  function! s:has_children(input) abort
    if index(s:REQUIRES_REGEX_ESCAPE, a:input) != -1
      let group = map(keys(s:runtime), {_,v -> v =~# '^\'.a:input})
    else
      let group = map(keys(s:runtime), {_,v -> v =~# '^'.a:input})
    endif
    return len(filter(group, 'v:val == 1')) > 1
  endfunction
else
  function! s:has_children(input) abort
    if index(s:REQUIRES_REGEX_ESCAPE, a:input) != -1
      let regex = '^\'.a:input
    else
      let regex = '^'.a:input
    endif
    let cnt = 0
    for each in keys(s:runtime)
      if each =~# regex
        let cnt += 1
        if cnt > 1
          return 1
        endif
      endif
    endfor
    return 0
  endfunction
endif

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
  if c == "\<BS>"
    call s:show_upper_level_mappings()
    return ''
  endif

  let input = which_key#char_handler#parse_raw(c)

  if s:has_children(input)
    while 1
      if !which_key#char_handler#timeout_for_next_char()
        let input .= which_key#char_handler#parse_raw(getchar())
      else
        break
      endif
    endwhile
  endif

  " Convert special keys to internal data structure that use String as the
  " key, e.g., "\<Tab>" => "<Tab>"
  if has_key(s:KEYCODES, input)
    let input = s:KEYCODES[input]
  elseif has_key(s:MERGE_INTO, input)
    let input = s:MERGE_INTO[input]
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
  let s:which_key_trigger .= ' '.(s:cur_char ==# ' ' ? '<Space>' : s:cur_char)
  call add(s:last_runtime_stack, copy(s:runtime))
  let s:runtime = a:next_runtime
  call which_key#window#show(s:runtime)
endfunction

function! s:handle_input(input) " {{{
  let ty = type(a:input)

  if ty == s:TYPE.dict
    call s:show_next_level_mappings(a:input)
    return
  endif

  if ty == s:TYPE.list && (!g:which_key_fallback_to_native_key ||
    \ g:which_key_fallback_to_native_key &&
    \ a:input[0] !=# 'which_key#error#missing_mapping()')
    call which_key#window#close()
    call s:execute(a:input[0])
  elseif g:which_key_fallback_to_native_key
    call which_key#window#close()
    " Is redraw needed here?
    " redraw!
    call s:execute_native_fallback(1)
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

function! s:execute_native_fallback(append) abort
  let l:reg = s:get_register()
  let l:fallback_cmd = s:vis.l:reg.s:count.substitute(substitute(s:which_key_trigger, ' ', '', 'g'), '<Space>', ' ', 'g')
  if (a:append)
    let l:fallback_cmd = l:fallback_cmd.get(s:, 'cur_char', '')
  endif
  try
    call feedkeys(l:fallback_cmd, 'n')
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
      if !empty(s:vis)
        let Cmd = line('v').','.line('.').Cmd
      endif
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
  for [mode, d] in items(s:cache)
    for k in keys(d)
      call which_key#mappings#parse(k, d, mode)
    endfor
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
