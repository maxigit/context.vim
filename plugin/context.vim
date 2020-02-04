" context.vim
" Shows the context of the currently visible buffer contents
" Author:  Christian Wellenbrock <christian.wellenbrock@gmail.com>
" License: MIT license

if !has('patch-7.4.1557')
    " here are some known features we use that impact what versions we can
    " support out of the box. for now we just bail out for earlier versions
    "     win_getid()     | neovim: +v0.1.5 | vim: +v7.4.1557
    "     v:vim_did_enter | neovim: +v0.1.7 | vim: +v7.4.1658
    finish
endif

call context#settings#parse()

" commands
command! -bar ContextActivate call context#activate()
command! -bar ContextEnable   call context#enable()
command! -bar ContextDisable  call context#disable()
command! -bar ContextToggle   call context#toggle()
command! -bar ContextUpdate   call context#update('command')


" mappings
if g:context.add_mappings
    " NOTE: in the zz/zt/zb mappings we invoke zz/zt/zb twice before calling
    " context#update(). unfortunately this is needed because it seems like Vim
    " sometimes gets confused if the window height changes shortly after zz/zt/zb
    " have been executed.
    nnoremap <silent>        <C-Y> <C-Y>:call context#update('C-Y')<CR>
    nnoremap <silent>        <C-E> <C-E>:call context#update('C-E')<CR>
    nnoremap <silent>        zz     zzzz:call context#update('zz')<CR>
    nnoremap <silent>        zt     ztzt:call context#update('zt')<CR>
    nnoremap <silent>        zb     zbzb:call context#update('zb')<CR>
endif


" autocommands
if g:context.add_autocmds
    augroup context.vim
        autocmd!
        autocmd VimEnter     * ContextActivate
        autocmd BufAdd       * call context#update('BufAdd')
        autocmd BufEnter     * call context#update('BufEnter')
        autocmd CursorMoved  * call context#update('CursorMoved')
        autocmd VimResized   * call context#update('VimResized')
        autocmd CursorHold   * call context#update('CursorHold')
        autocmd User GitGutter call context#update('GitGutter')
    augroup END
endif


" lazy loading was used
if v:vim_did_enter
    let g:context.enabled = 0 " plugin was effectively disabled before load
    ContextActivate
endif
