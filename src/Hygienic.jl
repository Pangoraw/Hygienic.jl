module Hygienic

Base.@kwdef struct ExpansionContext
    already_used::Set{Symbol} = Set{Symbol}()
    parent_context::Union{Nothing,ExpansionContext} = nothing
    name_map::Dict{Symbol,Symbol} = Dict{Symbol,Symbol}()
end
ExpansionContext(ctx::ExpansionContext) =
    ExpansionContext(; parent_context = ctx)

function get_parent_sym(ctx::ExpansionContext, s::Symbol)
    if ctx.parent_context === nothing
        push!(ctx.already_used, s)
    end
    get_sym(ctx.parent_context, s)
end

get_sym(ctx::ExpansionContext, s::Symbol) =
    haskey(ctx.name_map, s) ? ctx.name_map[s] : get_parent_sym(ctx, s)
    get_sym(::Nothing, s::Symbol) = s # the symbol is not aliased because it is not defined in the current expr

function set_sym!(ctx::ExpansionContext, s::Symbol)
    if s ∈ ctx.already_used
        error("$s was used before definition, use a different name to prevent confusion.")
    end

    if haskey(ctx.name_map, s)
        error("$s was already defined, note that branching is not supported.")
    end
    ctx.name_map[s] = gensym(s)
end

function sanitize_arglist!(ctx, ex::Expr)
    if ex.head == :tuple
       map!(
            s -> s isa Symbol ? set_sym!(ctx, s) : s,
            ex.args,
            ex.args,
       )
       return ex
    end

    error("Unvalid arglist type $(ex.head)")
end

isexpr(ex::Expr, heads) = any(h -> Meta.isexpr(ex, h), heads)
isexpr(ex::Expr, s::Symbol) = Meta.isexpr(ex, s)

function sanitize!(ctx, ex::Expr)::Expr
    if ex.head == :(=)
        value = ex.args[2]
        if ex.args[2] isa Expr
            sanitize!(ctx, ex.args[2])
        elseif value isa Symbol
            ex.args[2] = get_sym(ctx, ex.args[2])
        end

        assignee = ex.args[begin]
        if assignee isa Symbol
            ex.args[begin] = set_sym!(ctx, assignee)
        elseif Meta.isexpr(assignee, :tuple)
            sanitize_arglist!(ctx, assignee)
        elseif Meta.isexpr(assignee, :ref, 1)
            if assignee.args[1] isa Symbol
                assignee.args[1] = get_sym(ctx, assignee.args[1])
            end
        elseif Meta.isexpr(assignee, :$)
            nothing
        else
            dump(assignee)
            error("Unhandled assignee $(assignee)")
        end

        return ex
    elseif ex.head == :function
        func_ctx = ExpansionContext(ctx)
        sanitize_arglist!(func_ctx, ex.args[1])
        sanitize!(func_ctx, ex.args[2])
        return ex
    elseif ex.head == :(->)
        ctx = ExpansionContext(ctx)
        if ex.args[1] isa Expr
            sanitize_arglist!(ctx, ex.args[1])
        elseif ex.args[1] isa Symbol
            ex.args[1] = set_sym!(ctx, ex.args[1])
        end
        if ex.args[2] isa Expr
            sanitize!(ctx, ex.args[2])
        elseif ex.args[2] isa Symbol
            ex.args[2] = get_sym(ctx, ex.args[2])
        end
        return ex
    elseif isexpr(ex, (:ref,))
        if ex.args[1] isa Symbol
            ex.args[1] = get_sym(ctx, ex.args[1])
        elseif ex.args[1] isa Expr
            sanitize!(ctx, ex.args[1])
        end
        return ex
    elseif isexpr(ex, (:quote,))
        sanitize!(ctx, ex.args[1])
        return ex
    elseif isexpr(ex, :local)
        if ex.args[1] isa Expr
            sanitize!(ctx, ex.args[1])
        else
            map!(s -> set_sym!(ctx, s), ex.args, ex.args)
        end
        return ex
    elseif isexpr(ex, :do)
        sanitize!(ctx, ex.args[1])
        sanitize!(ctx, ex.args[2])
        return ex
    elseif isexpr(ex, (:block, :call, :if, :elseif, :&&, :||, :curly, :tuple, :vect))
        map!(
            a -> a isa Expr ? sanitize!(ctx, a) : a isa Symbol ? get_sym(ctx, a) : a,
            ex.args,
            ex.args,
        )
        return ex
    elseif isexpr(ex, :macrocall)
        # TODO: Support DSL macros
        map!(
            a -> a isa Expr ? sanitize!(ctx, a) : a isa Symbol ? get_sym(ctx, a) : a,
            ex.args,
            ex.args,
        )
        return ex
    elseif isexpr(ex, :.)
        child_ex = ex
        while isexpr(child_ex, :.) && child_ex.args[1] isa Expr
            child_ex = child_ex.args[1]
        end
        if child_ex.args[1] isa Symbol
            child_ex.args[1] = get_sym(ctx, child_ex.args[1])
        else
            error("Invalid selector $(child_ex.args[1])")
        end
        return ex
        return ex
    elseif isexpr(ex, :$)
        return ex
    else
        dump(ex)
        error("Unhandled expr type $(ex.head)")
    end
    error("unreachable")
end

"""
    @hygienize(ex::Expr)

A macro to transform a quote by replacing variable definitions with gensymed symbols.

```julia
julia> using Hygienic

julia> @hygienize quote
           x = 1
           x + y
       end
quote
    #= REPL[2]:2 =#
    var"##x#274" = 1
    #= REPL[2]:3 =#
    var"##x#274" + y
end
```
"""
macro hygienize(ex)
    @assert Meta.isexpr(ex, :quote) "Expected quote but got $(ex)"

    sanitize!(ExpansionContext(), ex)

    esc(ex)
end


let # For Precompilation?
    @hygienize quote
        x = 1
        x + y
    end
end

export @hygienize

end
