let s:TYPE = g:which_key#TYPE

" ASCII printable
let s:chars = map(range(32, 126), 'nr2char(v:val)')

let s:special_keys = {
      \ "\<Bar>": '<Bar>',
      \ "\<Bslash>": '<Bslash>',
      \ "\<Up>": '<Up>',
      \ "\<Down>": '<Down>',
      \ "\<Left>": '<Left>',
      \ "\<Right>": '<Right>',
      \ "\<LeftMouse>": '<LeftMouse>',
      \ "\<RightMouse>": '<RightMouse>',
      \ "\<MiddleMouse>": '<MiddleMouse>',
      \ "\<2-LeftMouse>": '<2-LeftMouse>',
      \ "\<C-LeftMouse>": '<C-LeftMouse>',
      \ "\<S-LeftMouse>": '<S-LeftMouse>',
      \ "\<ScrollWheelUp>": '<ScrollWheelUp>',
      \ "\<ScrollWheelDown>": '<ScrollWheelDown>',
      \ "\<C-Space>": '<C-Space>',
      \ "\<C-Left>": '<C-Left>',
      \ "\<C-Right>": '<C-Right>',
      \ "\<S-Left>": '<S-Left>',
      \ "\<S-Right>": '<S-Right>',
      \ }


" Generate a key mapping string based on a mode (empty string or one of C/S/M)
" and a key name.
function! s:gen_key_mapping(mode,key)
  let repr = '<'
  if a:mode != ''
    let repr = l:repr . a:mode . '-'
  endif
  if a:key ==# '"'
    let repr = l:repr . '\'
  endif
  let l:repr = l:repr . a:key . '>'
  let code = eval('"\' . l:repr . '"')
  return [l:repr, l:code]
endfunction

" Add M-* key mappings
for c in s:chars
  let [key, code] = s:gen_key_mapping('M',c)
  let s:special_keys[code] = key
endfor

" Add function keys and related combos
for fk in range(1,37)
  for p in [ "" , "S" , "C" , "M" ]
    let [key, code] = s:gen_key_mapping(p, 'F' . fk)
    let s:special_keys[code] = key
  endfor
endfor

function! which_key#char_handler#parse_raw(raw_char)
  if type(a:raw_char) == g:which_key#TYPE.number
    return nr2char(a:raw_char)
  elseif has_key(s:special_keys, a:raw_char)
    " Special characters
    return s:special_keys[a:raw_char]
  else
    return a:raw_char
  endif
endfunction

function! s:initialize_exit_code() abort
  if exists('g:which_key_exit')
    let ty = type(g:which_key_exit)
    if ty == s:TYPE.number
      let s:exit_code = [nr2char(g:which_key_exit)]
    elseif ty == s:TYPE.string
      let s:exit_code = [g:which_key_exit]
    elseif ty == s:TYPE.list
      let s:exit_code = map(g:which_key_exit, {_, val ->
        \ type(val) == s:TYPE.number ? nr2char(val) : val})
    else
      echohl ErrorMsg
      echon '[which-key] '.g:which_key_exit.' is invalid for option g:which_key_exit'
      echohl None
      return 1
    endif
  else
    " <Esc>, <C-[>: 27
    let s:exit_code = ["\<Esc>"]
  endif
endfunction

if !exists('s:exit_code')
  call s:initialize_exit_code()
endif

" Argument: v:t_number or v:t_string as returned by getchar()
function! which_key#char_handler#is_exit_code(raw_char) abort
  return -1 != index(s:exit_code,
    \ type(a:raw_char) == s:TYPE.number ? nr2char(a:raw_char) : a:raw_char)
endfunction

" Returns true if timed out
function! s:wait_with_timeout(timeout) abort
  let timeout = a:timeout
  while timeout > 0
    if getchar(1)
      return 0
    endif
    sleep 20m
    let timeout -= 20
  endwhile
  return !getchar(1)
endfunction

" Wait timtout to see if there are more input chars.
function! which_key#char_handler#wait_with_timeout() abort
  return s:wait_with_timeout(g:which_key_timeout)
endfunction

" Wait timtout to see if user is about to input more chars.
function! which_key#char_handler#timeout_for_next_char() abort
  return s:wait_with_timeout(g:which_key_timeout)
endfunction
