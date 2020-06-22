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

function! s:m_char(char)
  if a:char ==# '"'
    return ["<M-\">", "\<M-\">"]
  endif
  let m_char = '<M-' . a:char . '>'
  let m_char_code = eval('"\' . m_char . '"')
  return [m_char, m_char_code]
endfunction

for c in s:chars
  let [key, code] = s:m_char(c)
  let s:special_keys[code] = key
endfor

function! which_key#char_handler#parse_raw(raw_char)
  if type(a:raw_char) == g:which_key#TYPE.number
    " <Tab>, <C-I> = 9
    return a:raw_char == 9 ? '<Tab>' : nr2char(a:raw_char)
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
    if ty == s:TYPE.number || ty == s:TYPE.string
      let s:exit_code = [g:which_key_exit]
    elseif ty == s:TYPE.list
      let s:exit_code = g:which_key_exit
    else
      echohl ErrorMsg
      echon '[which-key] '.g:which_key_exit.' is invalid for option g:which_key_exit'
      echohl None
      return 1
    endif
  else
    " <Esc>, <C-[>: 27
    let s:exit_code = [27]
  endif
endfunction

if !exists('s:exit_code')
  call s:initialize_exit_code()
endif

" Argument: number
function! which_key#char_handler#is_exit_code(raw_char) abort
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

" Returns true if timed out
function! s:wait_with_timeout(timeout) abort
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

" Wait timtout to see if there are more input chars.
function! which_key#char_handler#wait_with_timeout() abort
  return s:wait_with_timeout(g:which_key_timeout)
endfunction

" Wait timtout to see if user is about to input more chars.
function! which_key#char_handler#timeout_for_next_char() abort
  return s:wait_with_timeout(g:which_key_timeout)
endfunction
