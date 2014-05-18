" twstack.vim
" Smart commands for moving around tab pages and windows.
"
" Maintainer: Steve Jones <sjout@slohj.org>
" Copyright (C) 2014 Steve Jones <sjout@slohj.org>
"
" License: This file is released under the Vim License.  See ':help license'
" for the full text.
"
" Changelog: {{{1
"
" 2014-05-18
"   Lock g:twlasttab, g:twtabstack, and t:twwinstack.
"
"   Add TWWstack(), Wstack, <C-W>O.
"
"   Add TWWsrot(), Wsrot, and <C-W>M.
"
"   Clean up layout and folding.
"
"   Make function descriptions match the help file.
"
"   Style fixes.
"
"   Version 1.00.
"
" 2014-05-17
"   Fix s:WinInit() check on w:twwinident, and locking.
"
"   Remove unnecessary silent commands.
"
"   Remove window stack and counter initialization from TabInit.
"
"   Add index out of range check for TWTsrot().
"
"   Add check for vim-7.4.
"
"   Add check for +autocmd.
"
"   Add TWWpush(), Wpush, <C-W>X.
"
"   Add TWWpop(), Wpop, <C-W>Y.
"
" 2014-05-15
"   Change all Ex commands from count to range to standardize the interface.
"
" 2014-05-14
"   Rewrite the reload checking.
"
"   Add function TWTstack().
"
"   Add commands Tstack and gO.
"
"   Add proper return values for all public functions.
"
"   Add TWTsrot(), Tsrot, and gM.
"
"   Fix creation of the window stacks.  Version 0.13.
"
"   Check for +windows on startup.
"
" 2014-05-13
"   Rewrite TWTpush(), :Tpush, and add normal command gX.
"
"   Add TWTpop(), :Tpop, and gY tab pop.
"
"   Add a count to TWTpop() and callers to access the Nth position in the tab
"   stack.  Bump the version number.
"
" 2014-05-12
"   Bump version to 0.10.  Add save, set restore for cpoptions.  Fix
"   autocommands triggering on startup with -o, -O, -p by using BufWinEnter to
"   trigger init for both windows and tabs.  Add initialization for the tab and
"   window stacks.  Add Ex command :Tpush.  Add public function TWTpush() to
"   empliment :Tpush.
"
" 2014-05-08
"   Use function s:LastTab() to set g:twlasttab only if t:twtabident has been
"   set.  This fixes a startup issue where tab are created on startup with the
"   -p option and TabEnter autocommands are not triggered until after the
"   windows have been created and the buffers loaded.
"
" 2014-05-07
"   Rewrite using t:tabident.  Make TabInit() script local.
"
"   Spelling fixes.
"
"   Add check to make sure that no tabs are assigned the tab identifier 0.
"   Add WinInit() and calling autocommand.
"
"   Try to create t:twwincount in WinInit() also.
"
"   Add function TWwinnr().  Add check for invalid tab identifier in TWtabnr.
"
"   Add rage argument to the public functions to prevent multiple calls over a
"   range.
"
" 2014-05-03
"   Add fold markers.
"
" 2014-04-29
"   First complete version.
"
"}}}1
"
" $Revision: 220 $
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" The current version of the script.
let s:version = 1.00
" Set to true to force reloading this script for development
"let s:development = 1

" Script Initialization. {{{1

" If in compatible mode finish.  Also if not compiled with windows support or
" auto commands.
if &cp || !has("windows") || !has("autocmd")
    finish
endif

" Needs Vim-7.4 or greater due to fixes to the auto command event trigger
" ordering for TabEnter, WinEnter, and BufWinEnter.
if v:version < 704
    echomsg "TWstack needs vim 7.4."
    finish
endif

" This is for reloading twstack.vim.
if exists("g:loaded_twstack")
    " Never reload this script if it is older than the previously loaded one.
    if s:version < g:loaded_twstack
	finish
    " If the versions are the same, only reload it if this is a development
    " version.
    elseif s:version == g:loaded_twstack
        if !exists("s:development") || s:development == 0
	    finish
        endif
    endif
endif

let g:loaded_twstack = s:version

let s:save_cpoptions = &cpoptions
set cpoptions&vim

" Global variables Initialization {{{1

" Only set the twtabcount on the first time through.
if !exists("g:twtabcount")
    let g:twtabcount = 1
    lockvar g:twtabcount
endif

" Initialize twlasttab to 0.  This makes "gy" work just like "gt" if for some
" reason t:twtabident doesn't get set.
if !exists("g:twlasttab")
    let g:twlasttab = 0
    lockvar g:twlasttab
endif

" Initialize the tab stack.
if !exists("g:twtabstack")
    let g:twtabstack = []
    lockvar g:twtabstack
endif

" FIXME: Should we initalize the winstack and wincount here?  That might
" eleminate the BufWinEnter auto command.

" Auto commands {{{1

augroup TWstack
    autocmd!
    " This is a catch all for on open with -o. -O, or -p to make sure all tabs
    " and windows are given an identifier.
    autocmd BufWinEnter * call <SID>WinInit() | call <SID>TabInit()
    " Initialize the tab identifier.  This is still needed for things such as
    " :tab split.
    autocmd TabEnter * call <SID>TabInit()
    " Initialize the window identifier.  This is still needed for :split and
    " such.
    autocmd WinEnter * call <SID>WinInit()
    " Set g:twlasttab when ever the tab page is changed.
    autocmd TabLeave * call <SID>LastTab()
augroup END

" Ex commands {{{1

" If a real range is used with -range then it is limited by the available
" number of lines in the active buffer.  <count> is the same as <line2> if a
" full range is given.  Counts, using either range or count, (single numbers),
" are not limited by the line numbers in the active buffer. ie: word counts.

" Tab Commands {{{2
command! -bang -bar -range=0 -nargs=0 Tpush call TWTpush(<bang>1, <count>)
command! -bang -bar -range=0 -nargs=0 Tpop call TWTpop(<bang>1, <count>)
command! -bar -nargs=0 Tstack call TWTstack()
command! -bar -range=1 -nargs=0 Tsrot call TWTsrot(<count>)

" Window Commands {{{2
command! -bang -bar -range=0 -nargs=0 Wpush call TWWpush(<bang>1, <count>)
command! -bang -bar -range=0 -nargs=0 Wpop call TWWpop(<bang>1, <count>)
command! -bar -range=0 -nargs=0 Wstack call TWWstack(<count>)
command! -bar -range=1 -nargs=0 Wsrot call TWWsrot(<count>)
" }}}2

" Global Maps {{{1

" Tab Mapp {{{2
nnoremap <silent> gy :<C-U>execute "normal " . TWtabnr(g:twlasttab) . "gt"<CR>
nnoremap <silent> gX :<C-U>execute v:count . "Tpush"<CR>
nnoremap <silent> gY :<C-U>execute v:count . "Tpop"<CR>
nnoremap <silent> gO :<C-U>Tstack<CR>
nnoremap <silent> gM :<C-U>execute v:count1 . "Tsrot"<CR>

" Window Maps {{{2
nnoremap <silent> <C-W>y :<C-U>wincmd p<CR>
nmap <silent> <C-W><C-Y> <C-W>y
nnoremap <silent> <C-W>X :<C-U>execute v:count . "Wpush"<CR>
nnoremap <silent> <C-W>Y :<C-U>execute v:count . "Wpop"<CR>
nnoremap <silent> <C-W>O :<C-U>execute v:count . "Wstack"<CR>
nnoremap <silent> <C-W>M :<C-U>execute v:count1 . "Wsrot"<CR>
" }}}2

" Functions {{{1

" Local Functions {{{2

" s:TabInit() {{{3
" Set t:twtabident if not already set.
function! s:TabInit()

    if !exists("t:twtabident")
	unlockvar g:twtabcount
	" This should never be true.
	if g:twtabcount == 0
	    let g:twtabcount += 1
	endif
	let t:twtabident = g:twtabcount
	lockvar t:twtabident
	let g:twtabcount += 1
	" Only 0 is an invalid identifier.  This should only be true on
	" overflow back to 0.
	if g:twtabcount == 0
	    let g:twtabcount += 1
	endif
	lockvar g:twtabcount
    endif

endfunction

" s:WinInit() {{{3
" Initialize the window stack, counter and identifier if not already done.
function! s:WinInit()

    " Initialize the counter and stack here since the TabEnter auto command
    " triggers after the WinEnter auto command in most circumstances.  Even if
    " it does not then this still works correctly.
    if !exists("t:twwincount")
	let t:twwincount = 1
	lockvar t:twwincount
    endif
    if !exists("t:twwinstack")
	let t:twwinstack = []
	lockvar t:twwinstack
    endif

    if !exists("w:twwinident")
	unlockvar t:twwincount
	" This should never be true!
	if t:twwincount == 0
	    let t:twwincount += 1
	endif
	let w:twwinident = t:twwincount
	lockvar w:twwinident
	let t:twwincount += 1
	" Only 0 is an invalid window identifier.  This should only be true on
	" overflow back to 0.
	if t:twwincount == 0
	    let t:twwincount += 1
	endif
	lockvar t:twwinxount
    endif

endfunction

" s:LastTab() {{{3
" Set g:lasttab only if the tab has been given an TWstack identifier.
function! s:LastTab()

    if exists("t:twtabident")
	unlockvar g:twlasttab
	let g:twlasttab = t:twtabident
	lockvar g:twlasttab
    endif

endfunction
" }}}3

" Public Functions {{{2

" Public Tab Functions {{{3

" TWtabnr({tabident}) {{{4
" Return the tab number of the tab with the TWstack identifier {tabident}.  If
" no tab matches the {tabident} return 0.
function! TWtabnr(tabident) range

    if a:tabident == 0
	return 0
    endif

    for l:tabnr in range(1, tabpagenr('$'))
	let l:ident = gettabvar(l:tabnr, "twtabident", 0)
	if l:ident == a:tabident
	    return l:tabnr
	endif
    endfor

    return 0

endfunction

" TWTpush({cflag}, {tabnr}) {{{4
" If {cflag} is 1, then push the current tab page identifier on to the tab
" page stack (g:twtabstack) and change to the tab page {tabnr}, if {tabnr} is
" 0 or the number of the current tab page, then do not try to change tab
" pages.
"
" If {cflag} is 0, push the identifier of tab page number {tabnr} and do not
" change tab pages.
"
" Returns the Vim tab page number of the tab page that was pushed on to the
" stack or 0 on error.
function! TWTpush(cflag, tabnr) range

    " Copy a:cflag for future manipulation.
    let l:cflag = a:cflag
    let l:curident = t:twtabident

    if a:tabnr == 0 || a:tabnr == tabpagenr()
	" If the target tab page number is 0, or is the current tab page, we
	" are only pushing the current tab page onto the stack and not
	" changing tab pages.
	let l:cflag = 0
    elseif a:tabnr > tabpagenr('$')
	" If the target tab page is greater than the actual number of tab
	" pages then we echo a message and return.
	echomsg "Invalid tab page number: " . a:tabnr
	return 0
    elseif !l:cflag 
	" If the cflag is false then we need to get the id for the target tab
	" page to push onto the stack.  Use 0 for the default just in case the
	" tab page identity was not set.  TWTpop will handle invalid tab
	" idents.
	let l:curident = gettabvar(a:tabnr, "twtabident", 0)
    endif

    " This is the actual push.
    unlockvar g:twtabstack
    call insert(g:twtabstack, l:curident)
    lockvar g:twtabstack
    if l:cflag
	execute "normal! " . a:tabnr . "gt"
    endif

    return TWtabnr(l:curident)

endfunction

" TWTpop({cflag}, {stackpos}) {{{4
" Pop the top of the tab page stack (g:twtabstack), and change to that tab
" page if {cflag} is 1.  If {cflag} is 0 then do not change tab pages.  If
" {stackpos} is not 0 then pop the entry indexed at {stackpos} (starting at
" 0).
"
" Returns the Vim tab page number of the tab page that was popped off the
" stack or 0 on error.
function! TWTpop(cflag, stackpos) range

    if len(g:twtabstack) > a:stackpos
	unlockvar g:twtabstack
	let l:tabident = remove(g:twtabstack, a:stackpos)
	lockvar g:twtabstack
	let l:tabnr = TWtabnr(l:tabident)
    else
	if a:stackpos == 0
	    echomsg "Tab stack is empty."
	else
	    echomsg "Out of range tab stack index: " . a:stackpos
	endif
	return 0
    endif

    " If we have an invalid tab number.
    if !l:tabnr
	if exists("g:TWtabpopuntilvalid") && g:TWtabpopuntilvalid != 0
	    " Pop until valid.
	    while !l:tabnr
		if len(g:twtabstack) > a:stackpos
		    unlockvar g:twtabstack
		    let l:tabident = remove(g:twtabstack, a:stackpos)
		    lockvar g:twtabstack
		    let l:tabnr = TWtabnr(l:tabident)
		else
		    echomsg "No valid tab identifier found."
		    return 0
		endif
	    endwhile
	else
	    echomsg "Invalid tab page identifier found."
	    return 0
	endif
    endif

    if a:cflag
	execute "normal! " . l:tabnr . "gt"
    endif

    return l:tabnr

endfunction

" TWTstack() {{{4
" Print out the contents of the tab page stack using the Vim tab page numbers.
" Invalid tab pages are listed as 0.  Returns the string that was displayed.
" The output is saved in Vim's |message-history|.
function! TWTstack() range

    if len(g:twtabstack) == 0
	echomsg "Tab page stack is empty."
	return 0
    endif

    let l:stackout = ""
    for l:tabident in g:twtabstack
	let l:stackout = l:stackout . TWtabnr(l:tabident) . " "
    endfor
    echomsg l:stackout
    return l:stackout

endfunction

" TWTsrot({stackpos}) {{{4
" Rotate the tab page stack so that the entry indexed at {stackpos}  (starting
" at 0) is at the top of the stack.  Display the new stack and return the same
" string.  The output is saved in Vim's |message-history|.  Return 0 on error.
function! TWTsrot(stackpos) range

    if len(g:twtabstack) < a:stackpos
	echomsg "Out of range tab stack index: " . a:stackpos
	return 0
    endif

    " Remove and append the top of the stack to a:stackpos - 1 inclusive.
    unlockvar g:twtabstack
    let g:twtabstack = extend(g:twtabstack,
		\ remove(g:twtabstack, 0, a:stackpos - 1))
    lockvar g:twtabstack

    " Print and return the new stack.
    let l:stackout = TWTstack()
    return l:stackout

endfunction
"}}}4

" Public Window Functions {{{3

" TWwinnr({winident}[, {tabnr}) {{{4
" Return the window number for the window with the TWstack identifier
" {winident}.  If {tabnr} is not present or 0, then return the window number
" for the current tab.  If no window matches {winident} then return 0.
function! TWwinnr(winident, ...) range

    if a:winident == 0
	return 0
    endif

    if a:0 == 0 || a:1 == 0
	let l:tabnr = tabpagenr()
    else
	let l:tabnr = a:1
    endif
    for l:winnr in range(1, tabpagewinnr(l:tabnr, '$'))
	let l:ident = gettabwinvar(l:tabnr, l:winnr, "twwinident", 0)
	if l:ident == a:winident
	    return l:winnr
	endif
    endfor

    return 0

endfunction

" TWWpush({cflag}, {winnr}) {{{4
" If {cflag} is 1, then push the current window identifier on to the current
" window stack (t:twwinstack) and change to the window {winnr}, if {winnr} is
" 0 or the number of the current window, then do not try to change windows.
"
" If {cflag} is 0, push the identifier of window number {winnr} and do not
" change windows.
" 
" Returns the Vim window number of the window that was pushed on to the stack
" or 0 on error.
function! TWWpush(cflag, winnr) range

    " Copy a:cflag for future manipulation.
    let l:cflag = a:cflag
    let l:curident = w:twwinident

    if a:winnr == 0 || a:winnr == winnr()
	" If the target window number is 0, or is the current window, we are
	" only pushing the current window onto the stack and not changing
	" windows.
	let l:cflag = 0
    elseif a:winnr > winnr('$')
	" If the target window page is greater than the actual number of
	" windows then we echo a message and return.
	echomsg "Invalid window number: " . a:winnr
	return 0
    elseif !l:cflag 
	" If the cflag is false then we need to get the id for the target
	" window to push onto the stack.  Use 0 for the default just in case
	" the window identity was not set.  TWWpop will handle invalid window
	" idents.
	let l:curident = getwinvar(a:winnr, "twwinident", 0)
    endif

    " This is the actual push.
    unlockvar t:twwinstack
    call insert(t:twwinstack, l:curident)
    lockvar t:twwinstack
    if l:cflag
	execute a:winnr . "wincmd w"
    endif

    return TWwinnr(l:curident)

endfunction

" TWWpop({cflag}, {stackpos}) {{{4
" Pop the top of the current window stack (t:twwinstack), and change to that
" window if {cflag} is 1.  If {cflag} is 0 then do not change windows.  If
" {stackpos} is not 0 then pop the entry indexed at {stackpos} (starting at
" 0).
" 
" Return the Vim window number of the window that was popped off the stack or
" 0 on error.
function! TWWpop(cflag, stackpos) range

    if len(t:twwinstack) > a:stackpos
	unlockvar t:twwinstack
	let l:winident = remove(t:twwinstack, a:stackpos)
	lockvar t:twwinstack
	let l:winnr = TWwinnr(l:winident)
    else
	if a:stackpos == 0
	    echomsg "Tab stack is empty."
	else
	    echomsg "Out of range window stack index: " . a:stackpos
	endif
	return 0
    endif

    " If we have an invalid window number.
    if !l:winnr
	if ( exists("t:TWwinpopuntilvalid") && t:TWwinpopuntilvalid != 0 ) ||
	    \ ( exists("g:TWwinpopuntilvalid") && g:TWwinpopuntilvalid != 0 )
	    " Pop until valid.
	    while !l:winnr
		if len(t:twwinstack) > a:stackpos
		    unlockvar t:twwinstack
		    let l:winident = remove(t:twwinstack, a:stackpos)
		    lockvar t:twwinstack
		    let l:winnr = TWwinnr(l:winident)
		else
		    echomsg "No valid window identifier found."
		    return 0
		endif
	    endwhile
	else
	    echomsg "Invalid window identifier found."
	    return 0
	endif
    endif

    if a:cflag
	execute l:winnr . "wincmd w"
    endif

    return l:winnr

endfunction

" TWWstack({tabnr}) {{{4
" Print out the contents of the window stack for tab page {tabnr} using the
" Vim window numbers.  If {tabnr} is 0 then use the window stack for the
" current tab page.  Invalid windows are listed as 0.  Returns the string that
" was displayed.  The output is saved in Vim's |message-history|.  Return 0 on
" error.
function! TWWstack(tabnr) range

    if a:tabnr > tabpagenr('$')
	echomsg "Invalid tab page number: " . a:tabnr
	return 0
    endif

    if a:tabnr == 0
	let l:tabnr = tabpagenr()
    else
	let l:tabnr = a:tabnr
    endif
    let l:winstack = gettabvar(l:tabnr, "twwinstack", [])
    if len(l:winstack) == 0
	echomsg "Window stack is empty."
	return 0
    endif

    let l:stackout = ""
    for l:winident in l:winstack
	let l:stackout = l:stackout . TWwinnr(l:winident, l:tabnr) . " "
    endfor
    echomsg l:stackout
    return l:stackout

endfunction

" TWWsrot({stackpos}) {{{4
" Rotate the window stack contained by the current tab page so that the entry
" indexed at {stackpos} (starting at 0) is at the top of the stack.  Display
" the new stack and return the same string.  The output is saved in Vim's
" |message-history|.  Return 0 on error.
function! TWWsrot(stackpos) range

    if len(t:twwinstack) < a:stackpos
	echomsg "Out of range window stack index: " . a:stackpos
	return 0
    endif

    " Remove and append the top of the stack to a:stackpos - 1 inclusive.
    unlockvar t:twwinstack
    let t:twwinstack = extend(t:twwinstack,
		\ remove(t:twwinstack, 0, a:stackpos - 1))
    lockvar t:twwinstack

    " Print and return the new stack.
    let l:stackout = TWWstack(0)
    return l:stackout

endfunction

" }}}2

" Mode Line and Cleanup {{{1

let &cpoptions = s:save_cpoptions
unlet s:save_cpoptions

" vim: tabstop=8 softtabstop=4 shiftwidth=4 filetype=vim foldmethod=marker:
