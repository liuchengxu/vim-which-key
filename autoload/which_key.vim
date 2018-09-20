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

  if a:bang
    let s:runtime = a:prefix
    call which_key#window#open(s:runtime)
    return
  endif

  let key = a:prefix

  let s:which_key_trigger = key ==# ' ' ? 'SPC' : key

  if !has_key(s:cache, key) || g:which_key_run_map_on_popup
    " First run
    let s:cache[key] = {}
    call which_key#map#parse(key, s:cache[key], s:vis ==# 'gv' ? 1 : 0)
  endif

  " s:runtime is a dictionary combining the native key mapping dictionary
  " parsed by vim-which-key itself with user defined prefix dictionary if avaliable.
  let s:runtime = s:create_runtime(key)
  call which_key#window#open(s:runtime)
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

  for k in keys(target)

    if type(target[k]) == s:TYPE.dict && has_key(native, k)

      if type(native[k]) == s:TYPE.dict
        if has_key(target[k], 'name')
          let native[k].name = target[k].name
        endif
        call s:merge(target[k], native[k])
      elseif type(native[k]) == s:TYPE.list
        if g:which_key_flatten == 0 || type(target[k]) == s:TYPE.dict
          let target[k.'m'] = target[k]
        endif
        let target[k] = native[k]
        if has_key(native, k.'m') && type(native[k.'m']) == s:TYPE.dict
          call s:merge(target[k.'m'], native[k.'m'])
        endif
      endif

    " Support add a description to an existing map without dual definition
    elseif type(target[k]) == s:TYPE.string && k != 'name'

      " <Tab> <C-I>
      if k == '<Tab>' && has_key(native, '<C-I>')
        let target[k] = [native['<C-I>'][0], target[k]]
      else
        let target[k] = [
              \ has_key(native, k) ? native[k][0] : 'which_key#util#mismatch()',
            \ target[k] ]
      endif

    endif

  endfor

  if has_key(native, '<C-I>')
    if !has_key(target, '<Tab>')
      let target['<Tab>'] = native['<C-I>']
    endif
    call remove(native, '<C-I>')
  endif

  call extend(target, native, 'keep')
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
