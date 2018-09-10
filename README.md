# vim-which-key

<!-- vim-markdown-toc GFM -->

* [Introduction](#introduction)
* [Pros.](#pros)
* [Installation](#installation)
    * [Plugin Manager](#plugin-manager)
    * [Package management](#package-management)
        * [Vim 8](#vim-8)
        * [NeoVim](#neovim)
* [Requirement](#requirement)
* [Usage](#usage)
    * [`timeoutlen`](#timeoutlen)
    * [Configuration](#configuration)
        * [Miminal Configuration](#miminal-configuration)
        * [Example](#example)
        * [Hide statusline](#hide-statusline)
    * [Commands](#commands)
    * [Options](#options)
* [Credit](#credit)

<!-- vim-markdown-toc -->

## Introduction

vim-which-key is vim port of [emacs-which-key](https://github.com/justbur/emacs-which-key) that displays available keybindings in popup.

[emacs-which-key](https://github.com/justbur/emacs-which-key) started as a rewrite of [guide-key](https://github.com/kai2nenobu/guide-key), very likely, [vim-which-key](https://github.com/liuchengxu/vim-which-key) heavily rewrote [vim-leader-guide](https://github.com/hecal3/vim-leader-guide) with a goal of going further in vim world. The features of vim-which-key has evolved a lot since then.

<p align="center"><img width="800px" src="https://raw.githubusercontent.com/liuchengxu/img/master/vim-which-key/vim-which-key.png"></p>

## Pros.

- Show all mappings following a prefix, e.g., `<leader>`, `<localleader>`, etc.
- Instant response for your every single input.
- Dynamic update on every call.
- Define group names and arbitrary descriptions.

## Installation

### Plugin Manager

Assuming you are using [vim-plug](https://github.com/junegunn/vim-plug):

```vim
Plug 'liuchengxu/vim-which-key'

" On-demand lazy load
Plug 'liuchengxu/vim-which-key', { 'on': ['WhichKey', 'WhichKey!'] }
```

For other plugin managers please refer to their document for more details.

### Package management

#### Vim 8

```bash
$ mkdir -p ~/.vim/pack/git-plugins/start
$ git clone https://github.com/liuchengxu/vim-which-key.git --depth=1 ~/.vim/pack/git-plugins/start/vim-which-key
```

#### NeoVim

```bash
$ mkdir -p ~/.local/share/nvim/site/pack/git-plugins/start
$ git clone https://github.com/liuchengxu/vim-which-key.git --depth=1 ~/.local/share/nvim/site/pack/git-plugins/start/vim-which-key
```

## Requirement

vim-which-key requires option `timeout` is on, see `:h timeout`.

Since `timeout` is on by default, all you need is not to `set notimeout` in your `.vimrc`.

## Usage

### `timeoutlen`

Let's say <kbd>SPC</kbd> is your leader key and you use it to trigger vim-which-key:

```vim
nnoremap <silent> <leader> :WhichKey '<Space>'<CR>
```

After pressing leader the guide buffer will pop up when there are no further keystrokes within `timeoutlen`.

```vim
" By default timeoutlen is 1000 ms
set timeoutlen=500
```

Pressing other keys within `timeoutlen` will either complete the mapping or open a subgroup. In the screenshot above <kbd>SPC</kbd><kbd>b</kbd> will open up the buffer menu.

Please note that no matter which mappings and menus you configure, your original leader mappings will remain unaffected. The key guide is an additional layer. It will only activate, when you do not complete your input during the timeoutlen duration.

### Configuration

#### Miminal Configuration

`:WhichKey` and `:WhichKeyVisual` are the primary way of interacting with this plugin.

Assuming your `leader` and `localleader` key are `<Space>` and `,`, respectively, even no description dictionary has been registered, all `<Space>` and `,` related mappings will be displayed regardless.

```vim
nnoremap <silent> <leader>      :<c-u>WhichKey '<Space>'<CR>
nnoremap <silent> <localleader> :<c-u>WhichKey  ','<CR>
```

The raw content displayed is normally not adequate to serve as a cheatsheet. See the following section for configuring it properly.

If no description dictionary is available, the right-hand-side of all mappings will be displayed:

<p align="center"><img width="800px" src="https://raw.githubusercontent.com/liuchengxu/img/master/vim-which-key/raw-spc-w.png"></p>

The dictionary configuration is necessary to provide group names or a description text.

```vim
let g:which_key_map['w'] = {
      \ 'name' : '+windows' ,
      \ 'w' : ['<C-W>w'     , 'other-window']          ,
      \ 'd' : ['<C-W>c'     , 'delete-window']         ,
      \ '-' : ['<C-W>s'     , 'split-window-below']    ,
      \ '|' : ['<C-W>v'     , 'split-window-right']    ,
      \ '2' : ['<C-W>v'     , 'layout-double-columns'] ,
      \ 'h' : ['<C-W>h'     , 'window-left']           ,
      \ 'j' : ['<C-W>j'     , 'window-below']          ,
      \ 'l' : ['<C-W>l'     , 'window-right']          ,
      \ 'k' : ['<C-W>k'     , 'window-up']             ,
      \ 'H' : ['<C-W>5<'    , 'expand-window-left']    ,
      \ 'J' : ['resize +5'  , 'expand-window-below']   ,
      \ 'L' : ['<C-W>5>'    , 'expand-window-right']   ,
      \ 'K' : ['resize -5'  , 'expand-window-up']      ,
      \ '=' : ['<C-W>='     , 'balance-window']        ,
      \ 's' : ['<C-W>s'     , 'split-window-below']    ,
      \ 'v' : ['<C-W>v'     , 'split-window-below']    ,
      \ '?' : ['Windows'    , 'fzf-window']            ,
      \ }
```

<p align="center"><img width="800px" src="https://raw.githubusercontent.com/liuchengxu/img/master/vim-which-key/spc-w.png"></p>

If you wish to hide a mapping from the menu set it's description to `'which_key_ignore'`. Useful for instance, to hide a list of <leader>[1-9] window swapping mappings. For example the below mapping will not be shown in the menu.
```vim
nnoremap <leader>1 :1wincmd w<CR>
let g:which_key_map.1 = 'which_key_ignore'
```

#### Example

Refer to [space-vim](https://github.com/liuchengxu/space-vim/blob/master/core/autoload/spacevim/map/leader.vim) for more detailed example.

```vim
" Define prefix dictionary
let g:which_key_map =  {}

" Second level dictionaries:
" 'name' is a special field. It will define the name of the group, e.g., leader-f is the "+file" group.
" Unnamed groups will show a default empty string.

" =======================================================
" Create menus based on existing mappings
" =======================================================
" You can pass a descriptive text to an existing mapping.

let g:which_key_map.f = { 'name' : '+file' }

nnoremap <silent> <leader>fs :update<CR>
let g:which_key_map.f.s = 'save-file'

nnoremap <silent> <leader>fd :e $MYVIMRC<CR>
let g:which_key_map.f.d = 'open-vimrc'

nnoremap <silent> <leader>oq  :copen<CR>
nnoremap <silent> <leader>ol  :lopen<CR>
let g:which_key_map.o = {
      \ 'name' : '+open',
      \ 'q' : 'open-quickfix'    ,
      \ 'l' : 'open-locationlist',
      \ }

" =======================================================
" Create menus not based on existing mappings:
" =======================================================
" Provide commands(ex-command, <Plug>/<C-W>/<C-d> mapping, etc.) and descriptions for existing mappings
let g:which_key_map.b = {
      \ 'name' : '+buffer' ,
      \ '1' : ['b1'        , 'buffer 1']        ,
      \ '2' : ['b2'        , 'buffer 2']        ,
      \ 'd' : ['bd'        , 'delete-buffer']   ,
      \ 'f' : ['bfirst'    , 'first-buffer']    ,
      \ 'h' : ['Startify'  , 'home-buffer']     ,
      \ 'l' : ['blast'     , 'last-buffer']     ,
      \ 'n' : ['bnext'     , 'next-buffer']     ,
      \ 'p' : ['bprevious' , 'previous-buffer'] ,
      \ '?' : ['Buffers'   , 'fzf-buffer']      ,
      \ }

let g:which_key_map.l = {
      \ 'name' : '+lsp'                                            ,
      \ 'f' : ['LanguageClient#textDocument_formatting()'     , 'formatting']       ,
      \ 'h' : ['LanguageClient#textDocument_hover()'          , 'hover']            ,
      \ 'r' : ['LanguageClient#textDocument_references()'     , 'references']       ,
      \ 'R' : ['LanguageClient#textDocument_rename()'         , 'rename']           ,
      \ 's' : ['LanguageClient#textDocument_documentSymbol()' , 'document-symbol']  ,
      \ 'S' : ['LanguageClient#workspace_symbol()'            , 'workspace-symbol'] ,
      \ 'g' : {
        \ 'name': '+goto',
        \ 'd' : ['LanguageClient#textDocument_definition()'     , 'definition']       ,
        \ 't' : ['LanguageClient#textDocument_typeDefinition()' , 'type-definition']  ,
        \ 'i' : ['LanguageClient#textDocument_implementation()'  , 'implementation']  ,
        \ },
      \ }
```

To make the guide pop up **Register the description dictionary for the prefix first** (assuming `Space` is your leader key):

```vim
call which_key#register('<Space>', "g:which_key_map")
nnoremap <silent> <leader> :<c-u>WhichKey '<Space>'<CR>
vnoremap <silent> <leader> :<c-u>WhichKeyVisual '<Space>'<CR>
```

The guide will be up to date at all times. Native vim mappings will always take precedence over dictionary-only mappings.

It is possible to call the guide for keys other than `leader`:

```vim
nnoremap <localleader> :<c-u>WhichKey  ','<CR>
vnoremap <localleader> :<c-u>WhichKeyVisual  ','<CR>
```

#### Hide statusline

<p align="center"><img width="800px" src="https://raw.githubusercontent.com/liuchengxu/img/master/vim-which-key/hide-statusline.png"></p>

Since the theme of provided statusline is not flexible and all the information has been echoed already, I prefer to hide it.

```vim
autocmd! FileType which_key
autocmd  FileType which_key set laststatus=0 noshowmode noruler
  \| autocmd BufLeave <buffer> set laststatus=2 showmode ruler
```

### Commands

See more details about commands and options via `:h vim-which-key`.

Command              | Description
:----                | :----:
`:WhichKey {prefix}` | Open the guide window for the given prefix
`:WhichKey! {dict}`  | Open the guide window for a given dictionary directly

### Options

Variable               | Default    | Description
:----                  | :----:     | :----:
`g:which_key_vertical` | 0          | show popup vertically
`g:which_key_position` | `botright` | split a window at the bottom
`g:which_key_hspace`   | 5          | minimum horizontal space between columns

## Credit

- [vim-leader-guide](https://github.com/hecal3/vim-leader-guide)
