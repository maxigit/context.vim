let s:nil_line = context#line#make(0, 0, '')

" collect all context lines
function! context#context#get(base_line) abort
    let base_line = a:base_line
    if base_line.number == 0
        return []
    endif

    let context = {}

    if !exists('b:context') || b:context.tick != b:changedtick
        " skips is a dictionary that maps a line to its next context line so
        " it allows us to skip large portions of the buffer instead of always
        " having to scan through all of it
        let b:context = {
                    \ 'tick':  b:changedtick,
                    \ 'skips': {},
                    \ }
    endif

    while 1
        let context_line = s:get_context_line(base_line)
        let b:context.skips[base_line.number] = context_line.number " cache this lookup

        if context_line.number == 0
            break
        endif

        let indent = context_line.indent
        if !has_key(context, indent)
            let context[indent] = []
        endif

        call insert(context[indent], context_line, 0)

        " for next iteration
        let base_line = context_line
    endwhile

    " join, limit and get context lines
    let lines = []
    for indent in sort(keys(context), 'N')
        let context[indent] = s:join(context[indent])
        let context[indent] = s:limit(context[indent], indent)
        call extend(lines, context[indent])
    endfor

    " limit total context
    let max = g:context.max_height
    if len(lines) > max
        let indent1 = lines[max/2].indent
        let indent2 = lines[-(max-1)/2].indent
        let ellipsis = repeat(g:context.char_ellipsis, max([indent2 - indent1, 3]))
        let ellipsis_line = context#line#make(0, indent1, repeat(' ', indent1) . ellipsis)
        call remove(lines, max/2, -(max+1)/2)
        call insert(lines, ellipsis_line, max/2)
    endif

    return lines
endfunction

function! s:get_context_line(line) abort
    " check if we have a skip available from the base line
    let skipped = get(b:context.skips, a:line.number, -1)
    if skipped != -1
        " call context#util#echof('  skipped', a:line.number, '->', skipped)
        return context#line#make(skipped, g:context.Indent_function(skipped), getline(skipped))
    endif

    " if line starts with closing brace or similar: jump to matching
    " opening one and add it to context. also for other prefixes to show
    " the if which belongs to an else etc.
    if context#line#should_extend(a:line.text)
        let max_indent = a:line.indent " allow same indent
    else
        let max_indent = a:line.indent - 1 " must be strictly less
    endif

    if max_indent < 0
        return s:nil_line
    endif

    " search for line with matching indent
    let current_line = a:line.number - 1
    while 1
        if current_line <= 0
            " nothing found
            return s:nil_line
        endif

        let indent = g:context.Indent_function(current_line)
        if indent > max_indent
            " use skip if we have, next line otherwise
            let skipped = get(b:context.skips, current_line, current_line-1)
            let current_line = skipped
            continue
        endif

        let line = getline(current_line)
        if context#line#should_skip(line)
            let current_line -= 1
            continue
        endif

        return context#line#make(current_line, indent, line)
    endwhile
endfunction

function! s:join(lines) abort
    " only works with at least 3 parts, so disable otherwise
    if g:context.max_join_parts < 3
        return a:lines
    endif

    " call context#util#echof('> join', len(a:lines))
    let pending = [] " lines which might be joined with previous
    let joined = a:lines[:0] " start with first line
    for line in a:lines[1:]
        if context#line#should_join(line.text)
            " add lines without word characters to pending list
            call add(pending, line)
            continue
        endif

        " don't join lines with word characters
        " but first join pending lines to previous output line
        let joined[-1] = s:join_pending(joined[-1], pending)
        let pending = []
        call add(joined, line)
    endfor

    " join remaining pending lines to last
    let joined[-1] = s:join_pending(joined[-1], pending)
    return joined
endfunction

function! s:join_pending(base, pending) abort
    " call context#util#echof('> join_pending', len(a:pending))
    if len(a:pending) == 0
        return a:base
    endif

    let max = g:context.max_join_parts
    if len(a:pending) > max-1
        call remove(a:pending, (max-1)/2-1, -max/2-1)
        call insert(a:pending, s:nil_line, (max-1)/2-1) " middle marker
    endif

    let joined = a:base
    for line in a:pending
        let joined.text .= ' '
        if line.number == 0
            " this is the middle marker, use long ellipsis
            let joined.text .= g:context.ellipsis5
        elseif joined.number != 0 && line.number != joined.number + 1
            " not after middle marker and there are lines in between: show ellipsis
            let joined.text .= g:context.ellipsis . ' '
        endif

        let joined.text .= context#line#trim(line.text)
        let joined.number = line.number
    endfor

    return joined
endfunction

function! s:limit(lines, indent) abort
    " call context#util#echof('> limit', a:indent, len(a:lines))

    let max = g:context.max_per_indent
    if len(a:lines) <= max
        return a:lines
    endif

    let diff = len(a:lines) - max

    let limited = a:lines[: max/2-1]
    call add(limited, context#line#make(0, a:indent, repeat(' ', a:indent) . g:context.ellipsis))
    call extend(limited, a:lines[-(max-1)/2 :])
    return limited
endif
endfunction
