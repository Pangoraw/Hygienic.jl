# Hygienic.jl

A small package to avoid the problem of leaking variables between macros. Consider the following macro `@b` that calls another macro `@a`. Since they both set a value to `x` and they share the same expansion context, the variable `##x#000` will be shared in both macros even though the name is gensymed. This can lead to confusing bugs when working with stacked macros.

```julia
macro a()
    quote
        x = :a
    end
end

macro b()
    quote
        x = :b
        @a()
        x # <- x is :a here
    end
end
```

## Solutions

Hygienic exports a single macro `@hygienize` to do the hygiene at the macro definition step instead of at macro call time. This makes sure that no variable will leak to another macro.

```julia
macro a()
    @hygienize quote
        x = :a
    end
end
```
