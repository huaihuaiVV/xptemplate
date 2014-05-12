XPTemplate priorit=all

let s:f = g:XPTfuncs()

fun! s:f.arg_complete(left, right)
    let index =  getline('.')[col('.') - 1] == a:left? col('.') - 1 : col('.') - 2
    let remain_str = getline('.')[index+1:col('$')]
    let ret = ''
    let str = getline('.')[:index]
    let res=[]
    let [ ml, mr ] = XPTmark()
    if str =~# '\m^\s*' . a:left
        let str = getline(line(".") - 1) . a:left
    endif
    if str == '' || str !~# '\m\k\+\s*' . a:left . '$'
        return ''
    endif
    let str = substitute(str, '\m\s*'. a:left . '\+$','', "")
    let name=substitute(str,'.\{-}\(\(\k\+::\)*\(\~\?\k*\|'.
                \'operator\s\+new\(\[]\)\?\|'.
                \'operator\s\+delete\(\[]\)\?\|'.
                \'operator\s*[[\]()+\-*/%<>=!~\^&|]\+'.
                \'\)\)\s*$','\1','')
    if name =~ '\<operator\>'  " tags have exactly one space after 'operator'
        let name=substitute(name,'\<operator\s*','operator ','')
    endif

    let funpat=escape(name,'[\*~^')
    try
        let ftags=taglist('^'.funpat.'$')
    catch /^Vim\%((\a\+)\)\=:E/
        " if error occured, reset tagbsearch option and try again.
        let bak=&tagbsearch
        set notagbsearch
        let ftags=taglist('^'.funpat.'$')
        let &tagbsearch=bak
    endtry
    if (type(ftags)==type(0) || ((type(ftags)==type([])) && ftags==[]))
        if &filetype=='cpp' && funpat!~'^\(catch\|if\|for\|while\|switch\)$'
            " Namespaces may be omitted
            try
                let ftags=taglist('::'.funpat.'$')
            catch /^Vim\%((\a\+)\)\=:E/
                " if error occured, reset tagbsearch option and try again.
                let bak=&tagbsearch
                set notagbsearch
                let ftags=taglist('::'.funpat.'$')
                let &tagbsearch=bak
            endtry
            if (type(ftags)==type(0) || ((type(ftags)==type([])) && ftags==[]))
                return
            endif
        endif
    endif
    let fil_tag=[]
    let has_f_kind=0
    for i in ftags
        if !has_key(i,'name') || !has_key(i, 'signature')
            continue
        endif
        if has_key(i,'kind')
            " p: prototype/procedure; f: function; m: member
            if ((i.kind=='p' || i.kind=='f') ||
                        \(i.kind == 'm' && has_key(i,'cmd') &&
                        \                  match(i.cmd,'(') != -1)) &&
                        \i.name=~funpat
                if &filetype!='cpp' || !has_key(i,'class') ||
                            \i.name!~'::' || i.name=~i.class
                    if i.kind=='p' && has_f_kind>0
                        continue
                    endif
                    let fil_tag+=[i]
                    if i.kind=='f'
                        let has_f_kind+=1
                    endif
                endif
            endif
        endif
    endfor
    if fil_tag==[]
        return
    endif
    if has_f_kind>0
        let index=0
        for tag in fil_tag
            if tag.kind == 'p'
                unlet fil_tag[index]
            endif
            let index += 1
        endfor
    endif
    for i in fil_tag
        if has_key(i,'kind') && has_key(i,'name') && has_key(i,'signature')
            let tmppat=substitute(escape(i.name,'[\*~^'),'^.*::','','')
            if &filetype == 'cpp'
                let tmppat=substitute(tmppat,'\<operator ','operator\\s*','')
                "let tmppat=substitute(tmppat,'^\(.*::\)','\\(\1\\)\\?','')
                let tmppat=tmppat . '\s*(.*'
                let tmppat='\([A-Za-z_][A-Za-z_0-9]*::\)*'.tmppat
            else
                let tmppat=tmppat . '\>.*'
            endif
            let name=substitute(i.cmd[2:-3],tmppat,'','').i.name.i.signature
        endif
        let name=substitute(name,'^\s\+','','')
        let name=substitute(name,'\s\+$','','')
        let name=substitute(name,'\s\+',' ','g')
        let file_line=i.filename
        if i.cmd > 0
            let file_line=file_line . ':' . i.cmd
        endif
        " let b:res+=[name.' ('.(index(fil_tag,i)+1).'/'.len(fil_tag).') '.file_line]
        let res+=[{'word':substitute(i.signature, '\m^(\s*\|\s*)$\|,\zs\s\+', '','g'), 'kind':i.kind, 'menu': name.' ('.(index(fil_tag,i)+1).'/'.len(fil_tag).') '.file_line}]
    endfor

    let dic = {}
    for r in res
        let dic[r.word] = r
    endfor
    let res = []
    for l in keys(dic)
       call add(res, dic[l])
    endfor

    if len(res) > 0
        if remain_str == ''
            let remain_str = a:right . ml . mr
        else
            let remain_str = ''
        endif
    else
        let remain_str = ''
    endif
    if len(res) > 1
        call complete(col('.'), res)
	augroup arg_complete
	autocmd CompleteDone <buffer>
	augroup end
        let ret =  getline('.')[index+1:col('.')]
	return ''
    elseif len(res) == 1
        let ret = res[0].word
    else
        let ret = ''
	echo "No signature found for symbol:" . name
    endif
    let ret = substitute(ret, '\m[^,]\+', ml .'&'.mr, 'g')
    let ret = substitute(ret, '\m^\|$', ml . '$SParg' . mr, 'g')
    let ret = substitute(ret, '\m,\zs', ml . '$SPop' . mr, 'g')
    return ret . remain_str
endfunction

XPT (	" func arg complete
XSET arg=arg_complete('(', ')')
(`arg^

