scriptencoding utf-8

"if exists('g:loaded_magit') || !executable('git') || &cp
"  finish
"endif
"let g:loaded_magit = 1
let g:magit_unstaged_buffer_name = "magit-unstaged"

function! s:set(var, default)
	if !exists(a:var)
		if type(a:default)
			execute 'let' a:var '=' string(a:default)
		else
			execute 'let' a:var '=' a:default
		endif
	endif
endfunction

call s:set('g:magit_enabled',               1)

function! magit#get_unstaged()
	if ( @% != g:magit_unstaged_buffer_name )
		echoerr "Not in magit buffer " . g:magit_unstaged_buffer_name . " but in " . @%
		return
	endif
	silent! execute "normal! ggdG"
	silent! read !git diff
	silent! read !git ls-files --others --exclude-standard | while read -r i; do git diff --no-color -- /dev/null "$i"; done
endfunction

function! magit#show_magit(orientation)
	vnew 
	setlocal buftype=nofile bufhidden=delete noswapfile filetype=gitdiff foldmethod=syntax nowrapscan
	execute "file " . g:magit_unstaged_buffer_name
	nnoremap <buffer> <silent> F :call magit#stage_file()<cr>
	call magit#get_unstaged()
	execute "normal! gg"
endfunction

" magit#search_block: helper function, to get a block of text, giving a start
" and multiple end pattern
" param[in] start_pattern: regex start, which will be search backward (cursor
" position is set to end of line before searching, to find the pattern if on
" the current line)
" param[in] end_pattern: list of end pattern. Each end pattern is a list with
" index 0 end pattern regex, and index 1 the number of line to exclude
" (essentially -1 or 0). Each pattern is searched in order. It'll choose the
" match with the minimum line number (smallest region search)
" param[in] upperlimit_pattern: regex of upper limit. If start_pattern line is
" inferior to upper_limit line, block is discarded
" return: a list. index 0: return status . index 1: a string containing the
" lines.
function! magit#search_block(start_pattern, end_pattern, upper_limit_pattern)
	let l:winview = winsaveview()

	let upper_limit=0
	if ( a:upper_limit_pattern != "" )
		let upper_limit=search(a:upper_limit_pattern, "bnW")
	endif

	" important if backward regex is at the beginning of the current line
	call cursor(0, 100)
	let start=search(a:start_pattern, "bW")
	if ( start == 0 )
		call winrestview(l:winview)
		return [1, ""]
	endif
	if ( start < upper_limit )
		call winrestview(l:winview)
		return [1, ""]
	endif


	let min=line('$')
	for end_p in a:end_pattern
		let curr_end=search(end_p[0], "nW")
		if ( curr_end != 0 && curr_end <= min )
			let end=curr_end + end_p[1]
			let min=curr_end
		endif
	endfor
	if ( end == 0 )
		call winrestview(l:winview)
		return [1, ""]
	endif

	let lines=getline(start, end)

	call winrestview(l:winview)
	return [0, join(lines, "\n")]
endfunction

function! magit#select_file()
	return magit#search_block("^diff --git", [ ["^diff --git", -1], [ "\\%$", 0 ] ], "")
endfunction

function! magit#stage_file()
	let [ret, selection] = magit#select_file()
	if ( ret != 0 )
		echoerr "Not in a file region"
		return
	endif
	call system("git apply --cached -", selection)
	call magit#get_unstaged()
endfunction

command! Magit call magit#show_magit("v")