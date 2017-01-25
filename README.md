## vim-erlang

This plugin include the following feature:

- customerized refactor
- customerized indenting

# indent style

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

yes, default to indent shiftwidth spaces in all situation

