if exists('g:loaded_stabs') && g:loaded_stabs
	finish
endif
let g:loaded_stabs = 1


if !exists('g:stabs_indent_regex')
	let g:stabs_indent_regex = '^\t*'
endif

if !exists('g:stabs_maps')
	let g:stabs_maps = 'tboOc='
endif

if !exists('g:stabs_insert_leave')
	let g:stabs_insert_leave = 1
endif


if g:stabs_maps =~ 't'
	inoremap <silent> <expr> <tab> StabsTab()
endif

if g:stabs_maps =~ 'b'
	inoremap <silent> <expr> <BS> StabsBS()
endif

" TODO: Properly add CTRL-d and CTRL-t mappings
"imap <silent> <expr> <c-d> :call <SID>SmartDeleteTab()<CR>
"imap <silent> <c-t> <SID>SmartInsertTab()
" fun! s:SmartDeleteTab()
"   let curcol=col('.')-&sw
"   let origtxt=getline('.')
"   let repl=matchstr(origtxt,'^\s\{-}\%'.(&sw+2)."v')
"   if repl == '' then
"     return "\<c-o>".':s/	*\zs	/'.repeat(' ',(&ts-&sw)).'/'."\<CR>\<c-o>".curcol.'|'
"   else
"     return "\<c-o>".':s/^\s\{-}\%'.(&sw+1)."v//\<CR>\<c-o>".curcol."|"
"   end
"
" endfun

fun! s:GetSoftTabStop()
	if (&sts > 0)
		return &sts
	elseif (&sw > 0)
		return &sw
	else
		return &ts
	endif
endfun

fun! s:GetIndentRegex()
	if exists('b:stabs_indent_regex')
		return b:stabs_indent_regex
	else
		return g:stabs_indent_regex
	endif
endfun

" Insert a smart tab.
fun! StabsTab()
	" Clear the status
	echo ''
	if strpart(getline('.'),0,col('.')-1) =~ s:GetIndentRegex().'$'
		return "\<Tab>"
	endif

	let sts=s:GetSoftTabStop()
	let sp=(virtcol('.') % sts)
	if sp==0 | let sp=sts | endif
	return repeat(' ', 1+sts-sp)
endfun

fun! Stab()
	return StabsTab()
endfun


if g:stabs_insert_leave
	fun! s:CheckLeaveLine(line)
		if ('cpo' !~ 'I') && exists('b:stabs_last_align') && (a:line == b:stabs_last_align)
			exe 's/'.s:GetIndentRegex().' *$//e'
		endif
	endfun

	" Remove indentation tabs when leaving insert mode
	augroup Stabs
		autocmd!
		autocmd InsertLeave * call <SID>CheckLeaveLine(line('.'))
	augroup END
endif


" Do a smart delete.
" The <BS> is included at the end so that deleting back over line ends
" works as expected.
fun! StabsBS()
	let uptohere=strpart(getline('.'),0,col('.')-1)
	" If only preceeded by whitespace, fall back on defaults (these then result
	" in the expected behavior).
	" If the preceding character is not a space, just delete (using defaults)
	let lastchar=matchstr(uptohere,'.$')
	if lastchar != ' ' || uptohere =~ '^\s*$' | return "\<BS>" | endif

	" Work out how many backspaces to use
	let sts=s:GetSoftTabStop()

	let ovc=virtcol('.')              " Find where we are
	let sp=((ovc-1) % sts)            " How many virtual characters to delete
	if sp==0 | let sp=sts | endif     " At least delete a whole tabstop
	let vc=ovc-sp                     " Work out the new virtual column
	" Find how many characters we need to delete (using \%v to do virtual column
	" matching, and making sure we don't pass an invalid value to vc)
	let uthlen=strlen(uptohere)
	let bs= uthlen-((vc<1)?0:(match(uptohere,'\%'.(vc).'v')))

	let uthlen=uthlen-bs
	"echom 'ovc = '.ovc.' sp = '.sp.' vc = '.vc.' bs = '.bs.' uthlen='.uthlen

	" Delete the specifed number of whitespace characters up to the first non-whitespace
	let ret="\<BS>"
	let bs=bs-1
	while bs>0
		let bs=bs-1
		if uptohere[uthlen+bs] !~ '\s' | break | endif
		let ret=ret."\<BS>"
	endwhile
	return ret
endfun

" Count the amount of columns occupied by whitespace characters from the start
" of line @lineNo. @lineNo is passed to `getline` and thus can also be an
" expression.
fun! s:StartColumn(lineNo)
	return strdisplaywidth(matchstr(getline(a:lineNo),s:GetIndentRegex().' *'))
endfun

" Align to column @n. Return a string of the amount of spaces needing to be
" inserted.
fun! StabsAlignTo(n)
	let co=virtcol('.')
	let ico=s:StartColumn('.')+a:n
	if co>ico
		let ico=co
	endif
	let spaces=ico-co
	return repeat(' ', spaces)
endfun

" Fix the alignment of line.
" Used when alignment whitespace is required .. like for unmatched brackets.
fun! StabsFixAlign(line)
	if a:line == line('.')
		let b:stabs_last_align=a:line
	elseif exists('b:stabs_last_align')
		unlet b:stabs_last_align
	endif

	if &expandtab || !(&autoindent || &indentexpr || &cindent)
		return ''
	endif

	let tskeep=&ts
	let swkeep=&sw
	let big=col([a:line, '$'])

	try
		" ts and sw should always be bigger than the amount of alignment spaces used
		if big == 0
			throw "Couldn't get line length"
		endif
		exe 'set ts='.big
		exe 'set sw='.big

		if &indentexpr != ''
			let v:lnum=a:line
			mark `
			sandbox exe 'let inda='.&indentexpr
			" The javascript formatter would change the rule number. This jumps back
			" to the previous line, preventing sudden cursor jumps
			normal ``
			if inda == -1
				let inda=indent(a:line-1)
			endif
		elseif &cindent
			let inda=cindent(a:line)
		elseif &lisp
			let inda=lispindent(a:line)
		elseif &autoindent
			let inda=indent(a:line)
		elseif &smarttab
			return ''
		else
			let inda=0
		endif
	finally
		let &ts=tskeep
		let &sw=swkeep
	endtry
	let indatabs=inda / big
	let indaspace=inda % big
	let indb=indent(a:line)

	if indatabs*&tabstop + indaspace == indb
		let txtindent=repeat("\<Tab>",indatabs).repeat(' ',indaspace)
		call setline(a:line, substitute(getline(a:line),'^\s*',txtindent,''))
	endif
	return ''
endfun

fun! s:SID()
	return matchstr(expand('<sfile>'), '<SNR>\zs\d\+\ze_SID$')
endfun
" Get the spaces at the end of the indent correct.
" This is trickier than it should be, but this seems to work.
fun! StabsCR()
	if getline('.') =~ s:GetIndentRegex().' *$'
		if ('cpo' !~ 'I') && exists('b:stabs_last_align') && (line('.') == b:stabs_last_align)
			return "^\<c-d>\<CR>"
		endif
		return "\<CR>"
	else
		let l:ret = "\<CR>\<c-r>=StabsFixAlign(line('.'))\<CR>\<END>"
		let l:gotobegin = "\<ESC>:normal!^\<CR>:startinsert\<CR>"
		let l:restofline = getline('.')[(col('.') - 1):]
		if len(l:restofline) && l:restofline !~ '^\s*$'
			" goto first nonblank only if <CR> came in middle of
			" line, ie had something besides whitespace after it
			let l:ret .= l:gotobegin
		endif
		return l:ret
	endif
endfun

if g:stabs_maps =~ 'c'
	inoremap <silent> <expr> <CR> StabsCR()
endif
" Notice \<lt>END> results in \<END>, which is the end key
if g:stabs_maps =~ 'o'
	nnoremap <silent> o o<c-r>=StabsFixAlign(line('.'))."\<lt>END>"<CR>
endif
if g:stabs_maps =~ 'O'
	nnoremap <silent> O O<c-r>=StabsFixAlign(line('.'))."\<lt>END>"<CR>
endif

" The = is implemented by remapping it so that it calls the original = and
" then checks all indents using StabsFixAlign.
if g:stabs_maps =~ '='
	nnoremap <silent> <expr> = StabsEqual()
endif
fun! StabsEqual()
	set operatorfunc=StabsRedoIndent
	" Call the operator func so we get the range
	return 'g@'
endfun

fun! StabsRedoIndent(type,...)
	set operatorfunc=
	let ln=line("'[")
	let lnto=line("']")
	" Do the original equals
	norm! '[=']

	if ! &expandtab
		" Then check the alignment.
		while ln <= lnto
			silent call StabsFixAlign(ln)
			let ln+=1
		endwhile
	endif
endfun

" Retab the indent of a file - ie only the first nonspace
fun! s:RetabIndent( bang, firstl, lastl, tab )
	let checkspace=((!&expandtab)? "^\<tab>* ": "^ *\<tab>")
	let l = a:firstl
	let force= a:tab != '' && a:tab != 0 && (a:tab != &tabstop)
	let checkalign = ( &expandtab || !(&autoindent || &indentexpr || &cindent))
	let newtabstop = (force?(a:tab):(&tabstop))
	while l <= a:lastl
		let txt=getline(l)
		let store=0
		if a:bang == '!' && txt =~ '\s\+$'
			let txt=substitute(txt,'\s\+$','','')
			let store=1
		endif
		if force || txt =~ checkspace
			let i=indent(l)
			let tabs= (&expandtab ? (0) : (i / newtabstop))
			let spaces=(&expandtab ? (i) : (i % newtabstop))
			let txtindent=repeat("\<tab>",tabs).repeat(' ',spaces)
			let store = 1
			let txt=substitute(txt,'^\s*',txtindent,'')
		endif
		if store
			call setline(l, txt )
			if checkalign
				call StabsFixAlign(l)
			endif
		endif

		let l=l+1
	endwhile
	if newtabstop != &tabstop | let &tabstop = newtabstop | endif
endfun


" Retab the indent of a file - ie only the first nonspace.
"   Optional argument specified the value of the new tabstops
"   Bang (!) causes trailing whitespace to be gobbled.
com! -nargs=? -range=% -bang -bar RetabIndent call <SID>RetabIndent(<q-bang>,<line1>, <line2>, <q-args> )


" vim: sts=2 sw=2 et
