" No usual did_ftplugin check here as we NEED to run this always

setlocal
  \ nonumber
  \ norelativenumber
  \ nolist
  \ nowrap
  \ nofoldenable
  \ nopaste
  \ nomodeline
  \ noswapfile
  \ nocursorline
  \ nocursorcolumn
  \ winfixwidth
  \ winfixheight
  \ colorcolumn=
  \ nobuflisted
  \ buftype=nofile
  \ bufhidden=unload

let &l:statusline = which_key#statusline()

" Problematic on vim and some older neovim version, refer to #40.
" Comment it for now.
" setlocal listchars=

hi WhichKeyTrigger ctermfg=232 ctermbg=178 guifg=#333300 guibg=#ffbb7d
hi WhichKeyName cterm=bold ctermfg=171 ctermbg=239 gui=bold guifg=#d75fd7 guibg=#4e4e4e
