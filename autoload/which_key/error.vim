function! which_key#error#report(err_msg) abort
  echohl ErrorMsg
  echom '[which-key] '.a:err_msg
  echohl None
endfunction

function! which_key#error#undefined_key(key) abort
  echohl ErrorMsg
  echom '[which-key] '.a:key.' is undefined'
  echohl None
endfunction

function! which_key#error#missing_mapping() abort
  echohl ErrorMsg
  echom '[which-key] Fail to execute, no such mapping'
  echohl None
endfunction
