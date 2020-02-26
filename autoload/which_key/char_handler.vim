let s:TYPE = g:which_key#util#TYPE

function! s:initialize_exit_code() abort
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
endfunction

" Argument: number
function! which_key#char_handler#is_exit_code(raw_char) abort
  if !exists('s:exit_code')
    call s:initialize_exit_code()
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

" Wait timtout to see if there are more input chars.
" Returns true if timed out
function! which_key#char_handler#wait_with_timeout(timeout)
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
