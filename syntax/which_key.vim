if exists('b:current_syntax')
  finish
endif
let b:current_syntax = 'which_key'

let s:sep = which_key#get_sep()

execute 'syntax match WhichKeySeperator' '/'.s:sep.'/' 'contained'
execute 'syntax match WhichKey' '/\(^\s*\|\s\{2,}\)\S.\{-}'.s:sep.'/' 'contains=WhichKeySeperator'
syntax match WhichKeyGroup / +[0-9A-Za-z_/-]*/
syntax region WhichKeyDesc start="^" end="$" contains=WhichKey, WhichKeyGroup, WhichKeySeperator

highlight default link WhichKey          Function
highlight default link WhichKeySeperator DiffAdded
highlight default link WhichKeyGroup     Keyword
highlight default link WhichKeyDesc      Identifier
