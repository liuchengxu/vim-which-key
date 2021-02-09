scriptencoding utf-8

if exists('g:loaded_vim_which_key')
  finish
endif
let g:loaded_vim_which_key = 1

let s:save_cpo = &cpo
set cpo&vim

let g:which_key_sep = get(g:, 'which_key_sep', '→')
let g:which_key_hspace = get(g:, 'which_key_hspace', 5)
let g:which_key_flatten = get(g:, 'which_key_flatten', 1)
let g:which_key_timeout = get(g:, 'which_key_timeout', &timeoutlen)
let g:which_key_max_size = get(g:, 'which_key_max_size', 0)
let g:which_key_vertical = get(g:, 'which_key_vertical', 0)
let g:which_key_position = get(g:, 'which_key_position', 'botright')
let g:which_key_centered = get(g:, 'which_key_centered', 1)
let g:which_key_sort_horizontal = get(g:, 'which_key_sort_horizontal', 0)
let g:which_key_run_map_on_popup = get(g:, 'which_key_run_map_on_popup', 1)
let g:which_key_align_by_seperator = get(g:, 'which_key_align_by_seperator', 1)
let g:which_key_ignore_invalid_key = get(g:, 'which_key_ignore_invalid_key', 1)
let g:which_key_fallback_to_native_key = get(g:, 'which_key_fallback_to_native_key', 0)
let g:which_key_default_group_name = get(g:, 'which_key_default_group_name', '+prefix')
let g:which_key_use_floating_win = (exists('*nvim_open_win') || exists('*popup_create')) && get(g:, 'which_key_use_floating_win', 1)
let g:which_key_floating_relative_win = get(g:, 'which_key_floating_relative_win', 0)
let g:which_key_disable_default_offset = get(g:, 'which_key_disable_default_offset', 0)
let g:WhichKeyFormatFunc = get(g:, 'WhichKeyFormatFunc', function('which_key#format'))

command! -bang -nargs=1 WhichKey call which_key#start(0, <bang>0, <args>)
command! -bang -nargs=1 -range WhichKeyVisual call which_key#start(1, <bang>0, <args>)

let &cpo = s:save_cpo
unlet s:save_cpo
