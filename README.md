# Vim Smarter Tabs

This is a redo of [dpc/vim-smarttabs](https://github.com/dpc/vim-smarttabs),
which in turn is a github copy of [Smart Tabs : Use tabs for indent, spaces for alignment](http://www.vim.org/scripts/script.php?script_id=231),
originally created by Michael Geddes. The aim of this redo is to improve the
interface and code quality.

## Introduction (adopted from vim.org)

There are many different arguments about tabs and stuff.  My current personal
preference is a choice of tabbing that is independent of anybody's viewing
setting.

For the beginning of the line, this means we can use <tabs> which will expand
whatever the reader wants it to.  Trying to line up tabs at the end of the line
is a little trickier, and making a few assumptions, my preference is to use
spaces there.

This script allows you to use your normal tab settings for the beginning of the
line, and have tabs expanded as spaces anywhere else.  This effectively
distinguishes `indent` from `alignment`.

* `<tab>`  Uses editor tab settings to insert a tab at the beginning of the
  line (before the first non-space character), and inserts spaces otherwise.
* `<BS>`  Uses editor tab settings to delete tabs or `expanded` tabs ala
  `smarttab`

`:RetabIndent[!] [tabstop]` - This is similar to the `:retab` command, with the
exception that it affects all and only whitespace at the start of the line,
changing it to suit your current (or new) `tabstop` and `expandtab` setting.
With the bang (!) at the end, the command also strips trailing  whitespace.

## Installation

### With Pathogen

```sh
mkdir -p ~/.vim/bundle && cd ~/.vim/bundle && git clone https://github.com/Thyrum/vim-stabs.git
```

Then run `:Helptags` from within vim to add helptags for the documentation.

### Using vim-plug

Add this to your `init.vim` or `.vimrc`:
```vim
Plug 'Thyrum/vim-stabs'
```

Then run `:PlugInstall` from within vim.

### Manually

Just copy `stabs.vim` into `~/.vim/plugin`. Notice that this will not
install the documentation.

## Tips

### coc.nvim

The tab- and enter-maps of vim-stabs will conflict with those of `coc.nvim`.
To fix this, change `coc.nvim`'s recommended `<Tab>` and `<CR>` remaps to the
following:

```vim
  let g:stabs_maps = 'boO='

  " Use tab for trigger completion with characters ahead and navigate.
  inoremap <silent><expr> <TAB>
        \ pumvisible() ? "\<C-n>" :
        \ <SID>check_back_space() ? StabsTab():
        \ coc#refresh()
  
  " Make <CR> auto-select the first completion item and notify coc.nvim to
  " format on enter.
  inoremap <silent><expr> <CR> pumvisible() ? coc#_select_confirm()
                           \: "\<C-g>u".StabsCR()."\<c-r>=coc#on_enter()\<CR>"
```
