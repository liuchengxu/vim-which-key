let s:mappings = {
      \ 'h': ['<Plug>(coc-explorer-key-n-h)', 'collapse node'],
      \ 'l': ['<Plug>(coc-explorer-key-n-l)', 'expand node'],
      \ 'o': ['<Plug>(coc-explorer-key-n-o)', 'expand & collapse node'],
      \ 'e': ['<Plug>(coc-explorer-key-n-e)', 'open'],
      \ 'gs': ['<Plug>(coc-explorer-key-n-gs)', 'reveal buffer in explorer'],
      \ 'gp': ['<Plug>(coc-explorer-key-n-gp)', 'preview'],
      \ 'y': ['<Plug>(coc-explorer-key-n-y)', 'copy full filepath to clipboard'],
      \ 'Y': ['<Plug>(coc-explorer-key-n-Y)', 'copy filename to clipboard'],
      \ 'c': ['<Plug>(coc-explorer-key-n-c)', 'copy file for paste'],
      \ 'x': ['<Plug>(coc-explorer-key-n-x)', 'cut file for paste'],
      \ 'p': ['<Plug>(coc-explorer-key-n-p)', 'paste files to here'],
      \ 'd': ['<Plug>(coc-explorer-key-n-d)', 'move file or directory to trash'],
      \ 'D': ['<Plug>(coc-explorer-key-n-D)', 'delete file or directory forever'],
      \ 'a': ['<Plug>(coc-explorer-key-n-a)', 'add a new file'],
      \ 'A': ['<Plug>(coc-explorer-key-n-A)', 'add a new directory'],
      \ 'r': ['<Plug>(coc-explorer-key-n-r)', 'rename'],
      \ '.': ['<Plug>(coc-explorer-key-n-.)', 'toggle hidden'],
      \ 'R': ['<Plug>(coc-explorer-key-n-R)', 'refresh'],
      \ }

let g:which_key#extensions#coc_explorer#config = {
      \ 'no_native': v:true,
      \ 'mappings': s:mappings,
      \ }
