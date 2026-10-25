set nomore
let s:buffer_number = 0

function! s:Buffer(lines) abort
  call feedkeys("\<Esc>", 'nx')
  let s:buffer_number += 1
  let l:path = $KEYMAP_TEST_FILES . '/case-' . s:buffer_number . '.txt'
  call writefile([], l:path)
  execute 'edit! ' . fnameescape(l:path)
  setlocal buftype= noswapfile wrap nonumber norelativenumber signcolumn=no foldenable&
  set columns=40 lines=20
  call setline(1, a:lines)
  call cursor(1, 1)
endfunction

function! s:Keys(keys) abort
  call feedkeys(a:keys, 'xt')
endfunction

call s:Buffer(['one two three'])
call s:Keys("j\<Esc>")
call assert_equal(3, col('.'), 'word end')

call s:Buffer([repeat('x', 180), 'second', 'third'])
call s:Keys('2n')
call assert_equal(1, line('.'), 'counted display movement stays on wrapped line')
call assert_true(col('.') > 40, 'counted display movement advances screen rows')
call s:Keys('gj')
call assert_equal(2, line('.'), 'logical down route')

call s:Buffer(['first', 'second', 'third'])
call s:Keys('dn')
call assert_equal(['third'], getline(1, '$'), 'operator down deletes logical lines')
call assert_equal('V', getregtype('"'), 'operator down is linewise')

call s:Buffer(['first', 'second'])
call s:Keys('dd')
call assert_equal(['second'], getline(1, '$'), 'unrelated delete operator remains native')

call s:Buffer(['one two'])
call s:Keys('duw')
call assert_equal(' two', getline(1), 'inner object prefix with native selector')

call s:Buffer(['ABC'])
call s:Keys('vuwl')
call assert_equal('abc', getline(1), 'visual lower-case conversion')
call s:Keys('vuwL')
call assert_equal('ABC', getline(1), 'visual upper-case conversion')

call s:Buffer(['abncd'])
call s:Keys('fn')
call assert_equal(3, col('.'), 'find argument is literal')
call s:Keys('me')
call s:Keys('i')
call s:Keys('`e')
call assert_equal(3, col('.'), 'mark name is literal')
call s:Keys('"nyy')
call assert_equal("abncd\n", getreg('n'), 'register name and yank stay native')

call s:Buffer(['tail'])
call s:Keys("unueijk\<Esc>")
call assert_equal('nueijktail', getline(1), 'inserted text is literal')

call s:Buffer(['ABC'])
call s:Keys("ghn\<Esc>")
call assert_equal('nBC', getline(1), 'Select-mode replacement is literal')

call s:Buffer(['one'])
call s:Keys("uX\<Esc>")
call s:Keys('l')
call assert_equal('one', getline(1), 'undo')
call s:Keys('L')
call assert_equal('Xone', getline(1), 'redo')

call s:Buffer(['first', 'second'])
call s:Keys('dL')
call s:Keys('x')
call assert_equal(['irst', 'second'], getline(1, '$'), 'vacant operator input cancels')

call s:Buffer(['top', 'bottom'])
vsplit
wincmd h
call s:Keys("\<C-w>i")
call assert_equal(2, winnr(), 'right window')
let s:windows = winnr('$')
call s:Keys("\<C-w>k")
call assert_equal(s:windows + 1, winnr('$'), 'displaced new-file split')
only!

let s:tree_root = $KEYMAP_TEST_FILES
execute 'NERDTree ' . fnameescape(s:tree_root)
call search('alpha.txt', 'w')
let s:start = line('.')
call s:Keys('n')
call assert_equal(s:start + 1, line('.'), 'NERDTree down')
call s:Keys('e')
call assert_equal(s:start, line('.'), 'NERDTree up')
let s:windows = winnr('$')
call s:Keys('u')
call assert_equal(s:windows + 1, winnr('$'), 'NERDTree displaced split')
call assert_equal('alpha.txt', expand('%:t'), 'NERDTree split opens selected file')

if !empty(v:errors)
  for s:error in v:errors
    echom s:error
  endfor
  cquit
endif
echom 'PASS: native Vim editing, operator, literal, window and NERDTree behavior'
if !empty($KEYMAP_TEST_RESULT)
  call writefile(['PASS: native Vim editing, operator, literal, window and NERDTree behavior'], $KEYMAP_TEST_RESULT)
endif
qa!
