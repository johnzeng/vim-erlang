# vim-erlang

This plugin include the following feature:

- customerized refactor
- customerized indenting

The indent plugin is shipped by vim, I just do some modify on it to meet my requirement.

The refactoring plugin is mostly copied from [ oscarh/vimerl ]( https://github.com/oscarh/vimerl )
## indent style

instead of the default vi indent setting, this plugin use the following indent style:

```
func(a,b,c) ->
    X = maps:map(fun(K,V) ->
        case b of
            a ->
            b ->
        end
    end, maps:new())
```

Yes, default to indent shiftwidth spaces under all situation

If you prefer to use the shipped indent setting, just add the following setting to your `.vimrc` file

```
let g:erlang_indent_style="system"
``` 

## refactor tips:

- make sure `localhost` is pointing to your pc , so the erlang rpc can be sent correctly
- make sure you have set up the wrangler right
- make sure you have `erl_call` under your working $PATH (if you use brew to install erlang on mac, you will have to find and add it by yourself)

### feature trigger
If you don't wanna use this feature and you don't wanna wast your system resource, set up the following command in your `.vimrc` file

```
let g:erlangRefactoring=0
```

### setting up wrangler
**important** , the `wrangler api` might change by time, my working wrangler is cloned from [ refactoring tool ]( https://github.com/RefactoringTools/wrangler ) , commit hash code is `50a7a39c5df2cc1a03d9f40e8a201427b8d5ecc0`. so you may wanna get it like: 

```
git clone https://github.com/RefactoringTools/wrangler
cd wrangler
git checkout 50a7a39c5df2cc1a03d9f40e8a201427b8d5ecc0
./configure && make
```

just making this project is enough, set up the repo's directory in your `.vimrc` file like this:

`let g:erlangWranglerPath='/path/to/compiled/wrangler'
`

### setting up search path
If you follow the OTP's file struct, this refactor plugin should work fine for you , if not, you may need to add the source code search path like this:

```
let g:refactor_search_path = ["source/path/to/search","another/source/path/to/search"]
```

### key binding

All of the refactoring features' key binding starts by `<leader>a`, 

```
<leader>ae extra function
<leader>af rename function
<leader>av rename variable
<leader>at tuple function
<leader>am rename module
<leader>ap renmae process
```


