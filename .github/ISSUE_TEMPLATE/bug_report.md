---
name: Bug report
about: Create a report to help us improve
title: ''
labels: ''
assignees: ''

---

_Instructions: Replace the template text and remove irrelevant text (including this line)_
**Warning: if you don't fill this issue template and provide the reproducible steps the issue could be closed directly.**

**Environment (please complete the following information):**
 - OS: ???

 - (Neo)Vim version: ???
<!-- Output of `git rev-parse --short HEAD` in vim-which-key directory. -->
 - vim-which-key version: ???
<!-- Without a minimal vimrc, this issue might be closed directly. -->
 - Have you reproduced with a minimal vimrc: ???

**Describe the bug**
A clear and concise description of what the bug is.

**To Reproduce**
Steps to reproduce the behavior:

1. Create the minimal vimrc `min.vim`:

```vim
set nocompatible
set runtimepath^=/path/to/vim-which-key
syntax on
filetype plugin indent on

" Here place the configuration that can cause this issue.
```

2. Start (neo)vim with command: `vim -u min.vim`

3. Type '....'

4. See error

**Expected behavior**
A clear and concise description of what you expected to happen.

**Screenshots**
If applicable, add screenshots to help explain your problem.

**Additional context**
Add any other context about the problem here.
