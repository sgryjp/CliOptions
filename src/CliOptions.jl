module CliOptions


Combiner = Union{Function,Nothing}

"""
    CliOptionError(msg::String)

An error occurred inside `CliOptions` module. Message describing the error is available in
the `msg` field.
"""
struct CliOptionError <: Exception
    msg::String
end

Base.showerror(io::IO, e::CliOptionError) = print(io, e.msg)


"""
    CliOptions.AbstractOption

Abstract supertype representing a command line option. Concrete subtypes are:

- [`Option`](@ref) ... an option which takes a following argument as its value
- [`FlagOption`](@ref) ... an option of which existence becomes its boolean value
- [`CounterOption`](@ref) ... an option of which number of usage becomes its integer value
- [`Positional`](@ref) ... an argument which is not an option

Note that a group of options represented with `AbstractOptionGroup` is also an
`AbstractOption` so it can be used to construct `CliOptionSpec`.
"""
abstract type AbstractOption end

function Base.show(io::IO, x::AbstractOption)
    print(io, typeof(x), "(", join([":" * encode(name) for name in x.names], ','), ")")
end
Base.show(x::AbstractOption) = show(stdout, x)


"""
    CliOptions.AbstractOptionGroup

Abstract type representing a group of command line options. Concrete subtypes are:

- [`OptionGroup`](@ref)
- [`MutexGroup`](@ref)
"""
abstract type AbstractOptionGroup <: AbstractOption end

function Base.show(io::IO, x::AbstractOptionGroup)
    print(io, typeof(x), "(", join([repr(o) for o in x], ','), ")")
end
Base.show(x::AbstractOptionGroup) = show(stdout, x)

Base.length(o::AbstractOptionGroup) = length(o.options)

function Base.iterate(o::AbstractOptionGroup)
    1 ≤ length(o.options) ? (o.options[1], 2) : nothing
end

function Base.iterate(o::AbstractOptionGroup, state)
    state ≤ length(o.options) ? (o.options[state], state + 1) : nothing
end


"""
    CliOptions.ParseResult()

Dict-like object holding parsing result of command line options. The values can be accessed
using either:

1. dot notation (e.g.: `result.num_workers`)
2. bracket notation (e.g.: `result["num_workers"]`)

This is the type [`parse_args`](@ref) function returns. If the function detected errors,
it stores error messages into `_errors` field of this type. This may be useful if you let
the program continue running on errors (see `onerror` parameter of `CliOptionSpec`).
"""
mutable struct ParseResult
    _defaults
    _argvals
    _resolved
    _errors

    function ParseResult(argvals = Dict{String,Any}(),
                         defaults = Dict{String,Tuple{Any,Combiner}}(),
                         errors = String[])
        # Generate merged dictionary
        resolved = Dict{String,Any}()
        for (k, (v, _)) in defaults
            resolved[k] = v
        end
        for (k, v) in argvals
            if haskey(defaults, k)
                _, combiner = defaults[k]
                if combiner !== nothing
                    resolved[k] = combiner(resolved[k], v)  # combine the old with the new
                else
                    resolved[k] = v  # overwrite the old with the new
                end
            else
                resolved[k] = v  # add new entry for the new default value
            end
        end

        new(defaults, argvals, resolved, errors)
    end
end

function Base.show(io::IO, x::ParseResult)
    print(io, typeof(x), "(", join([":$k" for k in sort(propertynames(x))], ','), ")")
end

Base.show(x::ParseResult) = show(stdout, x)

function Base.getindex(result::ParseResult, key)
    k = key isa Symbol ? String(key) : key
    getindex(result._resolved, k)
end

function Base.propertynames(result::ParseResult; private = false)
    props = [Symbol(k) for (k, v) in getfield(result, :_resolved)]
    if private
        push!(props, :_argvals, :_defaults, :_errors, :_resolved)
    end
    sort!(props)
end

function Base.getproperty(result::ParseResult, name::Symbol)
    if name in (:_argvals, :_defaults, :_errors, :_resolved)
        return getfield(result, name)
    else
        return getfield(result, :_resolved)[String(name)]
    end
end


"""
    Option([type=String,] primary_name::String, secondary_name::String = "";
           default = missing, until = nothing, requirement = nothing, help = "")

Type representing a command line option whose value is a following argument. Two forms of
option notations are supported:

1. Short form (e.g.: `-n 42`)
   - Starting with a dash, one character follows it
   - A following command line argument will be the option's value
2. Long form (e.g.: `--foo-bar`)
   - Starting with two dash, dash-separated words follow them
   - Value can be specified as one of the two forms below:
     1. `--foo-bar value`; a following command line argument becomes the option's value
     2. `--foo-bar=value`; characters after an equal sign following the option name becomes
        the option's value

An Option can have two names. `primary_name` is typically a short form notation and is also
used to express the option in a usage message or error messages. `secondary_name` is
typically a long form notation and is also used to generate a value name in a usage message.
For example, if names of an option are `-n` and `--foo-bar`, it will appear in a usage
message as `-n FOO_BAR`. If you want to define an option which have only a long form
notation, specify it as `primary_name` and omit `secondary_name`.

If `type` parameter is set, option values will be converted to the type inside `parse_args`
and will be stored in returned `ParseResult`.

`default` parameter is used when `parse_args` does not see the option in the given command
line arguments. If a value other than `missing` was specified, it will be the option's
value. If it's `missing`, absense of the option is considered as an error; in other word,
the option becomes a *required* option. The default value of `default` parameter is
`missing`.

If `until` parameter is specified, following arguments will be collected into a vector to be
the option's value until an argument which is or one of the `until` parameter appears. In
this case, type of the option's value will be `Vector{T}` where `T` is the type specified
with `type` parameter. `until` parameter can be a string, a vector or tuple of strings, or
`nothing`. Default value is `nothing`; no collection will be done.

`requirement` determines how to validate the option's value. If the option's value does not
meet the requirement, it's considered an error. `requirement` can be one of:

1. `nothing`
   - Any value will be accepted
2. A list of acceptable values
   - Arguments which matches one of the values will be accepted
   - Any iterable can be used to specify acceptable values
   - Arguments will be converted to the specified type and then compared to each element of
     the list using function `==`
3. A `Regex`
   - Arguments which matches the regular expression will be accepted
   - Pattern matching will be done for unprocessed input string, not type converted one
4. A custom validator function
   - It validates command line arguments one by one
   - It can return a `Bool` which indicates whether a given argument is acceptable or not
   - It also can return a `String` describing why a given command line argument is NOT
     acceptable, or an empty `String` if it is acceptable

If you want an option which does not take a command line argument as its value, see
[`FlagOption`](@ref) and [`CounterOption`](@ref)
"""
struct Option <: AbstractOption
    names::Union{Tuple{String},Tuple{String,String}}
    T::Type
    default::Any
    until::Union{Nothing,String,Vector{String},Tuple{Vararg{String}}}
    requirement::Any
    help::String

    function Option(T::Type, primary_name::String, secondary_name::String = "";
                    default::Any = missing, until = nothing,
                    requirement::Any = nothing, help::String = "")
        names = secondary_name == "" ? (primary_name,) : (primary_name, secondary_name)
        _validate_option_names(Option, names)
        new(names, T, default, until, requirement, help)
    end
end

function Option(primary_name::String, secondary_name::String = "";
                default::Any = missing, until = nothing, requirement::Any = nothing,
                help::String = "")
    Option(String, primary_name, secondary_name;
           default = default, until = until, requirement = requirement, help = help)
end

function set_default!(d::Dict{String,Tuple{Any,Combiner}}, o::Option)
    for name in o.names
        d[encode(name)] = (o.default, nothing)
    end
end

function consume!(d::Dict{String,Any}, o::Option, args, ctx)
    @assert 1 ≤ length(args)
    @assert "" ∉ o.names
    @assert all(o isa AbstractOption for o in ctx.all_options)

    if args[1] ∉ o.names
        return 0
    end
    if o.until === nothing
        # Ensure at least one argument is available
        if length(args) < 2
            throw(CliOptionError("A value is needed for option \"$(args[1])\""))
        end

        # Update counter
        ctx.usage_count[o] = get(ctx.usage_count, o, 0) + 1

        # Parse the argument as value
        value = _parse(o.T, args[2], o.requirement; optname = args[1])
        for name in o.names
            d[encode(name)] = value
        end
        return 2
    else
        _match(term, arg) = begin
            if term isa String
                arg == term
            else
                arg in term
            end
        end

        # Scan for the last argument
        term_index = 2
        while !_match(o.until, args[term_index])
            if length(args) == term_index
                msg = "\"$(o.names[1])\" needs \"$(o.until)\" as an end-mark"
                throw(CliOptionError(msg))
            end
            term_index += 1
        end

        # Update counter
        ctx.usage_count[o] = get(ctx.usage_count, o, 0) + 1

        # Parse the arguments as value
        values = o.T[]
        for j = 2:term_index-1
            value = _parse(o.T, args[j], o.requirement; optname = args[1])
            push!(values, value)
        end
        for name in o.names
            d[encode(name)] = values
        end
        return term_index
    end
end

function check_usage_count(o::Option, ctx)
    # Throw if it's required but was omitted
    if ismissing(o.default) && get(ctx.usage_count, o, 0) ≤ 0
        msg = "Option \"$(o.names[1])\" must be specified"
        throw(CliOptionError(msg))
    end
end

function to_usage_tokens(o::Option)
    tokens = [o.names[1] * " " * _to_placeholder(o.names)]
    if !ismissing(o.default)
        tokens[1] = "[" * tokens[1]
        tokens[end] = tokens[end] * "]"
    end
    tokens
end
function print_description(io::IO, o::Option)
    print_description(io, o.names, _to_placeholder(o.names), o.help)
end


"""
    HelpOption(names = ("-h", "--help"); [help::String])

Options for printing help (usage) message.

The default value of `names` are `-h` and `--help`. If you do not like to have `-h` for
printing help message, just give `--help` for `names` parameter (i.e.:
`HelpOption("--help"; ...)`).

The default behavior for a help option is printing help message and exiting. If you do not
like this behavior, use `onhelp` parameter on constructing [`CliOptionSpec`](@ref).
"""
struct HelpOption <: AbstractOption
    names
    help::String

    function HelpOption(names::String...; help::String = "Show usage message and exit")
        if length(names) == 0
            names = ("-h", "--help")
        end
        _validate_option_names(HelpOption, names)
        new(names, help)
    end
end

function set_default!(d::Dict{String,Tuple{Any,Combiner}}, o::HelpOption)
    for name in o.names
        d[encode(name)] = (false, nothing)
    end
end

function consume!(d::Dict{String,Any}, o::HelpOption, args, ctx)
    @assert 1 ≤ length(args)
    @assert "" ∉ o.names
    @assert all(o isa AbstractOption for o in ctx.all_options)

    arg = args[1]
    if startswith(arg, "--")
        if arg in o.names
            value = true
        else
            return 0
        end
    elseif startswith(arg, "-")
        @assert length(arg) == 2  # Splitting -abc to -a, -b, -c is done by parse_args()
        if arg in o.names
            value = true
        else
            return 0
        end
    else
        return 0
    end

    # Update counter
    count::Int = get!(ctx.usage_count, o, 0)
    ctx.usage_count[o] = count + 1

    # Construct parsed values
    for name in o.names
        d[encode(name)] = value
    end
    return 1
end

function to_usage_tokens(o::HelpOption)
    ["[" * o.names[1] * "]"]
end

function print_description(io::IO, o::HelpOption)
    print_description(io, o.names, "", o.help)
end


"""
    FlagOption(primary_name::String, secondary_name::String = "";
               negators::Union{String,Vector{String}} = String[],
               help = "",
               negator_help = "")

`FlagOption` represents a so-called "flag" command line option. An option of this type takes
no value and whether it was specified becomes a boolean value.
"""
struct FlagOption <: AbstractOption
    names::Union{Tuple{String},Tuple{String,String}}
    negators::Vector{String}
    help::String
    negator_help::String

    function FlagOption(primary_name::String, secondary_name::String = "";
                        negators::Union{String,Vector{String}} = String[],
                        help = "", negator_help = "")
        names = secondary_name == "" ? [primary_name] : [primary_name, secondary_name]
        if negators isa String
            negators = [negators]
        end
        _validate_option_names(FlagOption, names, negators)
        if negator_help == ""
            negator_help = "Negate usage of " * names[1] * " option"
        end
        new(Tuple(names), [n for n in negators], help, negator_help)
    end
end

function set_default!(d::Dict{String,Tuple{Any,Combiner}}, o::FlagOption)
    for name in o.names
        d[encode(name)] = (false, nothing)
    end
    for name in o.negators
        d[encode(name)] = (true, nothing)
    end
end

function consume!(d::Dict{String,Any}, o::FlagOption, args, ctx)
    @assert 1 ≤ length(args)
    @assert "" ∉ o.names
    @assert all(o isa AbstractOption for o in ctx.all_options)

    arg = args[1]
    if startswith(arg, "--")
        if arg in o.names
            value = true
        elseif arg in o.negators
            value = false
        else
            return 0
        end
    elseif startswith(arg, "-")
        @assert length(arg) == 2  # Splitting -abc to -a, -b, -c is done by parse_args()
        if arg in o.names
            value = true
        elseif arg in o.negators
            value = false
        else
            return 0
        end
    else
        return 0
    end

    # Update counter
    count::Int = get!(ctx.usage_count, o, 0)
    ctx.usage_count[o] = count + 1

    # Construct parsed values
    for name in o.names
        d[encode(name)] = value
    end
    for name in o.negators
        d[encode(name)] = !value
    end
    return 1
end

check_usage_count(o::Union{FlagOption,HelpOption}, ctx) = nothing

function to_usage_tokens(o::FlagOption)
    latter_part = 1 ≤ length(o.negators) ? " | " * o.negators[1] : ""
    ["[" * o.names[1] * latter_part * "]"]
end

function print_description(io::IO, o::FlagOption)
    print_description(io, o.names, "", o.help)
    if 1 ≤ length(o.negators)
        print_description(io, o.negators, "", o.negator_help)
    end
end


"""
    CounterOption([type=Int,] primary_name::String, secondary_name::String = "";
                  decrementers::Union{String,Vector{String}} = String[],
                  default::Signed = 0,
                  help::String = "",
                  decrementer_help = "")

A type represents a flag-like command line option. Total number of times a `CounterOption`
was specified becomes the option's value.
"""
struct CounterOption <: AbstractOption
    names::Union{Tuple{String},Tuple{String,String}}
    decrementers::Vector{String}
    default::Signed
    T::Type
    help::String
    decrementer_help::String

    function CounterOption(T::Type, primary_name::String, secondary_name::String = "";
                           decrementers::Union{String,Vector{String}} = String[],
                           default::Signed = 0,
                           help::String = "",
                           decrementer_help::String = "")
        names = secondary_name == "" ? [primary_name] : [primary_name, secondary_name]
        if decrementers isa String
            decrementers = [decrementers]
        end
        _validate_option_names(CounterOption, names, decrementers)
        if !(T <: Signed)
            throw(ArgumentError("Type of a CounterOption must be a subtype of Signed:" *
                                " \"$T\""))
        end
        if decrementer_help == ""
            decrementer_help = "Opposite of " * names[1] * " option"
        end
        new(Tuple(names), [n for n in decrementers], T(default), T, help, decrementer_help)
    end
end

function CounterOption(primary_name::String, secondary_name::String = "";
                       decrementers::Union{String,Vector{String}} = String[],
                       default::Signed = 0,
                       help::String = "",
                       decrementer_help::String = "")
    CounterOption(Int, primary_name, secondary_name;
                  decrementers = decrementers, default = default, help = help,
                  decrementer_help = decrementer_help)
end

function set_default!(d::Dict{String,Tuple{Any,Combiner}}, o::CounterOption)
    for name in o.names
        d[encode(name)] = (o.T(o.default), +)  # Intentionally allowing overflow/underflow
    end
end

function consume!(d::Dict{String,Any}, o::CounterOption, args, ctx)
    @assert 1 ≤ length(args)
    @assert "" ∉ o.names
    @assert all(o isa AbstractOption for o in ctx.all_options)

    arg = args[1]
    diff = 0
    if startswith(arg, "--")
        if arg in o.names
            diff = +1
        elseif arg in o.decrementers
            diff = -1
        end
    elseif startswith(arg, "-")
        @assert length(arg) == 2  # Splitting -abc to -a, -b, -c is done by parse_args()
        if arg in o.names
            diff = +1
        elseif arg in o.decrementers
            diff = -1
        end
    end
    if diff == 0
        return 0
    end
    value = get(d, encode(o.names[1]), 0) + diff
    if !(typemin(o.T) ≤ value ≤ typemax(o.T))
        throw(CliOptionError("Too many \"$(arg)\""))
    end

    # Update counter
    ctx.usage_count[o] = get(ctx.usage_count, o, 0) + 1

    # Construct parsed values
    for name in o.names
        d[encode(name)] = o.T(value)
    end
    return 1
end

check_usage_count(o::CounterOption, ctx) = nothing

function to_usage_tokens(o::CounterOption)
    latter_part = 1 ≤ length(o.decrementers) ? " | " * o.decrementers[1] : ""
    ["[" * o.names[1] * latter_part * "]"]
end

function print_description(io::IO, o::CounterOption)
    print_description(io, o.names, "", o.help)
    if 1 ≤ length(o.decrementers)
        print_description(io, o.decrementers, "", o.decrementer_help)
    end
end


"""
    Positional([type=String,] singular_name, plural_name = "";
               multiple = false, requirement = nothing,
               default = missing, help = "")

`Positional` represents a command line argument which are not an option name nor an option
value.

`requirement` determines how to validate positional arguments. See explanation of
[Option](@ref) for more detail.
"""
struct Positional <: AbstractOption
    names::Union{Tuple{String},Tuple{String,String}}
    T::Type
    multiple::Bool
    requirement::Any
    default::Any
    help::String

    function Positional(T::Type,
                        singular_name::String,
                        plural_name::String = "";
                        multiple::Bool = false,
                        requirement::Any = nothing,
                        default::Any = missing,
                        help::String = "")
        if singular_name == ""
            throw(ArgumentError("Name of a Positional must not be empty"))
        elseif startswith(singular_name, '-')
            throw(ArgumentError("Name of a Positional must not start with a dash: " *
                                singular_name))
        elseif startswith(plural_name, '-')
            throw(ArgumentError("Name of a Positional must not start with a dash: " *
                                plural_name))
        elseif singular_name == plural_name
            throw(ArgumentError("Duplicate names for a Positional found: " *
                                singular_name))
        end

        if plural_name == ""
            return new((singular_name,), T, multiple, requirement, default, help)
        else
            return new((singular_name, plural_name),
                       T, multiple, requirement, default, help)
        end
    end
end

function Positional(singular_name::String,
                    plural_name::String = "";
                    multiple::Bool = false,
                    requirement::Any = nothing,
                    default::Any = missing,
                    help::String = "")
    Positional(String, singular_name, plural_name;
               multiple = multiple, requirement = requirement, default = default,
               help = help)
end

function set_default!(d::Dict{String,Tuple{Any,Combiner}}, o::Positional)
    for name in o.names
        d[encode(name)] = (o.default, nothing)
    end
end

function consume!(d::Dict{String,Any}, o::Positional, args, ctx)
    @assert 1 ≤ length(args)
    @assert "" ∉ o.names
    @assert all(o isa AbstractOption for o in ctx.all_options)

    # Skip if this node is already processed
    count::Int = get(ctx.usage_count, o, 0)
    max_nvalues = o.multiple ? Inf : 1
    if max_nvalues ≤ count
        return 0
    end
    ctx.usage_count[o] = count + 1

    # Scan values to consume
    values = Vector{o.T}()
    nconsumed = 0
    for arg in args[1:(o.multiple ? length(args) : 1)]
        token_type = _check_option_name(arg)
        if token_type == :double_dash
            # Raise flag if it's first double-dash otherwise consume it
            if ctx.double_dash_found == false
                ctx.double_dash_found = true
                nconsumed += 1
                continue
            end
        elseif ctx.double_dash_found != true && token_type == :valid
            break  # Do not consume an argument which looks like an option
        elseif ctx.double_dash_found != true && token_type == :negative
            if any(name == arg for opt in ctx.all_options for name in opt.names)
                break  # Do not consume an option which looks like a negative number
            end
        end
        push!(values, _parse(o.T, arg, o.requirement))
        nconsumed += 1
    end
    if length(values) == 0
        return 0  # No arguments consumable
    end

    # Store parse result
    for name in o.names
        d[encode(name)] = o.multiple ? values : values[1]
    end

    return nconsumed
end

function check_usage_count(o::Positional, ctx)
    # Throw if it's required but was omitted
    if ismissing(o.default) && get(ctx.usage_count, o, 0) ≤ 0
        msg = "\"$(o.names[1])\" must be specified"
        throw(CliOptionError(msg))
    end
end

function to_usage_tokens(o::Positional)
    name = _to_placeholder(o.names[1])
    if o.multiple
        if ismissing(o.default)
            [name * " [$name...]"]
        else
            ["[$name...]"]
        end
    elseif ismissing(o.default)
        [name]
    else
        ["[$name]"]
    end
end

function print_description(io::IO, o::Positional)
    print_description(io, (_to_placeholder(o.names[1]),), "", o.help)
end

function Base.show(io::IO, x::Positional)
    print(io, typeof(x), "(", join([":$name" for name in x.names], ','), ")")
end
Base.show(x::Positional) = show(stdout, x)


"""
    OptionGroup(options::AbstractOption...; name::String = "")

`OptionGroup` contains one or more `AbstractOption`s and accepts command line arguments if
one of the options is accepted. In other word, this is an OR operator for `AbstractOption`s.
"""
struct OptionGroup <: AbstractOptionGroup
    names::Tuple{String}
    options

    OptionGroup(options::AbstractOption...; name::String = "") = new((name,), options)
end

function set_default!(d::Dict{String,Tuple{Any,Combiner}}, o::OptionGroup)
    for option in o.options
        set_default!(d, option)
    end
end

function consume!(d::Dict{String,Any}, o::OptionGroup, args, ctx)
    for option in o.options
        num_consumed = consume!(d, option, args, ctx)
        if 0 < num_consumed
            return num_consumed
        end
    end
    return 0
end

function check_usage_count(o::OptionGroup, ctx)
    for option in o.options
        check_usage_count(option, ctx)
    end
end

function to_usage_tokens(o::OptionGroup)
    tokens = Vector{String}()
    for option in o.options
        append!(tokens, to_usage_tokens(option))
    end
    tokens
end

function print_description(io::IO, o::OptionGroup)
    if o.names[1] != ""
        println(io, "  " * o.names[1] * ":")
    end
    for option in o.options
        print_description(io, option)
    end
end


"""
    MutexGroup(options::AbstractOption...; name::String = "")

`MutexGroup` contains one or more `AbstractOption`s and accepts command line arguments only
if exactly one of the options was accepted.
"""
struct MutexGroup <: AbstractOptionGroup
    name::String
    options

    MutexGroup(options::AbstractOption...; name::String = "") = new(name, options)
end

function set_default!(d::Dict{String,Tuple{Any,Combiner}}, o::MutexGroup)  # Same as from OptionGroup
    for option in o.options
        set_default!(d, option)
    end
end

function consume!(d::Dict{String,Any}, o::MutexGroup, args, ctx)  # Same as from OptionGroup
    for option in o.options
        num_consumed = consume!(d, option, args, ctx)
        if 0 < num_consumed
            return num_consumed
        end
    end
    return 0
end

function check_usage_count(o::MutexGroup, ctx)
    exceptions = Exception[]
    for option in o.options
        try
            check_usage_count(option, ctx)
        catch ex
            push!(exceptions, ex)
        end
    end
    if length(o.options) - length(exceptions) != 1
        buf = IOBuffer()
        print(buf, "Exactly one of ")
        print(buf, join([x.names[1] for x in o.options], ", ", " or "))
        print(buf, " must be specified")
        msg = String(take!(buf))
        throw(CliOptionError(msg))
    end
end

function to_usage_tokens(o::MutexGroup)
    tokens = Vector{String}()
    append!(tokens, to_usage_tokens(o.options[1]))
    for option in o.options[2:end]
        push!(tokens, "|")
        append!(tokens, to_usage_tokens(option))
    end
    tokens[1] = "{" * tokens[1]
    tokens[end] = tokens[end] * "}"
    tokens
end

function print_description(io::IO, o::MutexGroup)  # Same as from OptionGroup
    if o.name != ""
        println(io, "  " * o.name * ":")
    end
    for option in o.options
        print_description(io, option)
    end
end


"""
    CliOptionSpec(options::AbstractOption...;
                  program = PROGRAM_FILE,
                  use_double_dash = true,
                  onhelp = 0,
                  onerror = 1)

A type representing a command line option specification.

`program` parameter is used for the program name which appears in help (usage) message. If
omitted, `Base.PROGRAM_FILE` will be used.

If `use_double_dash` parameters is `true`, no argument after double dash (`--`) will be
recognized as an option. In this case, the double dash itself will not parsed as an option
nor a positional argument. Note that only the first double dash is treated specially so
double dashes which appeares after it will be recognized as positional arguments. This is
especially useful for programs which launches another program using command line arguments
given to itself.

`onhelp` parameter controls what to do if a [`HelpOption`](@ref) was used. It can be either:

1. An `Integer`
   - The running program will print help message and exit using it as the status code.
2. `nothing`
   - Nothing happens. In this case, the `HelpOption` is treated just like a
     [`FlagOption`](@ref) so you can examine whether it was used or not by examining
     [`ParseResult`](@ref) using its name.
3. A function which takes no arguments
   - Do whatever you want in the function.

The default value is `0`.

`onerror` parameter controls the action when an error was detected on parsing arguments.
Available choices are:

1. An `Integer`
   - The running program will print an error message along with a help message and exit with
     the status code.
2. `nothing`
   - Ignore errors. Note that error messages are stored in `_errors` field of the returning
     [`ParseResult`](@ref) so you can examine them later.
3. A function which takes an error message
   - Example 1) `onerror = (msg) -> (@warn msg)` ... Warn the error but continue processing
   - Example 2) `onerror = error` ... Throw `ErrorException` using `Base.exit`, instead of
     exiting

The default value is `1`.

#### Example: Using a function for `onhelp` parameter

```jldoctest
using CliOptions

spec = CliOptionSpec(
    HelpOption(),
    onhelp = () -> begin
        print_usage(spec, verbose = false)
        # exit(42)  # Use exit() to let the program exit inside parse_args()
    end,
    program = "onhelptest.jl"
)
options = parse_args(spec, ["-h"])  # The program does not exit here
println(options.help)

# output

Usage: onhelptest.jl [-h]
true
```

#### Example: Using a function for `onerror` parameter

```jldoctest
using CliOptions

spec = CliOptionSpec(
    Option("--required-argument"),
    onerror = (msg) -> println("Warning: \$msg"),
)
options = parse_args(spec, String[])
println(repr(options.required_argument))

# output

Warning: Option \"--required-argument\" must be specified
missing
```
"""
struct CliOptionSpec
    root::OptionGroup
    program::String
    use_double_dash::Bool
    onhelp::Any
    onerror::Any

    function CliOptionSpec(options::AbstractOption...;
                           program = PROGRAM_FILE,
                           use_double_dash = true,
                           onhelp = 0,
                           onerror = 0)
        if program == ""
            program = "PROGRAM"  # may be called inside REPL
        end
        new(OptionGroup(options...), program, use_double_dash, onhelp, onerror)
    end
end

function Base.show(io::IO, x::CliOptionSpec)
    print(io, typeof(x), "(", join([repr(o) for o in x.root], ','), ")")
end
Base.show(x::CliOptionSpec) = show(stdout, x)


"""
    print_usage([io::IO], spec::CliOptionSpec; verbose = true)

Write usage (help) message to `io`. Set `false` to `verbose` if you want to print only the
first line of the usage message. If `io` is omitted, message will be written `stdout`.
"""
function print_usage(io::IO, spec::CliOptionSpec; verbose = true)
    print(io, "Usage: $(spec.program) ")
    println(io, join(Iterators.flatten(to_usage_tokens(o) for o in spec.root), " "))
    if verbose
        println(io)
        println(io, "Options:")
        print_description(io, spec.root)
    end
end

function print_usage(spec::CliOptionSpec; verbose = true)
    print_usage(stdout, spec, verbose = verbose)
end


mutable struct ParseContext
    usage_count
    all_options
    double_dash_found::Union{Nothing,Bool}

    ParseContext(use_double_dash = false) = new(Dict{AbstractOption,Int}(),
                                                Vector{AbstractOption}(),
                                                use_double_dash ? false : nothing)
end

"""
    parse_args(spec::CliOptionSpec, args = ARGS)

Parse `args` according to the `spec`.

`spec` is an instance of [`CliOptionSpec`](@ref) which defines how to parse command line
arguments. It is constructed with one or more concrete subtypes of
[`AbstractOption`](@ref)s. See document of `AbstractOption` for full list of its subtypes.

`args` is the command line arguments to be parsed. If omitted, `Base.ARGS` – the command
line arguments passed to the Julia script – will be parsed.

This function returns a [`ParseResult`](@ref) after parsing. It is basically a Dict-like
object holding the values of options.

```jldoctest
using CliOptions

spec = CliOptionSpec(
    Option(Int, "-n", "--num-workers"),
    FlagOption("-i", "--ignore-case"; negators = "--case-sensitive"),
    Positional("root"),
    Positional("pattern", "patterns"; multiple = true);
    program = "myfind"
)

args = parse_args(spec, split("-n 3 -i /var/log *.log", " "))
println("num_workers: ", args.num_workers)
println("ignore_case: ", args.ignore_case)
println("root: ", args.root)
println("patterns: ", args.patterns)

# output

num_workers: 3
ignore_case: true
root: /var/log
patterns: ["*.log"]
```
"""
function parse_args(spec::CliOptionSpec, args = ARGS)
    ctx = ParseContext(spec.use_double_dash)
    defaults = Dict{String,Tuple{Any,Combiner}}()
    argvals = Dict{String,Any}()
    errors = Vector{String}()

    # Store all options in a vector and pick special options
    help_option = nothing
    foreach_options(spec.root) do o
        push!(ctx.all_options, o)
        if o isa HelpOption
            help_option = o
        end
    end

    # Normalize argument list
    args = _normalize_args(args)

    # Collect default values
    for option in spec.root
        set_default!(defaults, option)
    end

    # Parse arguments
    i = 1
    while i ≤ length(args)
        try
            num_consumed = consume!(argvals, spec.root, args[i:end], ctx)
            if num_consumed ≤ 0
                throw(CliOptionError("Unrecognized argument: \"$(args[i])\""))
            end
            i += num_consumed
        catch ex
            push!(errors, _stringify(ex))
            i += 1
        end
    end

    # Take care of omitted options
    for option in (o for o in spec.root.options if get(ctx.usage_count, o, 0) ≤ 0)
        try
            check_usage_count(option, ctx)
        catch ex
            ex::CliOptionError
            push!(errors, ex.msg)
        end
    end

    # Finally, handle help option and errors
    if 1 ≤ get(ctx.usage_count, help_option, 0)
        if spec.onhelp isa Integer
            print_usage(stdout, spec)
            _exit(spec.onhelp)
        elseif spec.onhelp !== nothing
            spec.onhelp()
        end
    end
    for msg in errors
        if spec.onerror isa Integer
            printstyled(stderr, "ERROR: "; color = Base.error_color())
            println(stderr, msg)
            print_usage(stderr, spec)
            _exit(spec.onerror)
        elseif spec.onerror !== nothing
            spec.onerror(msg)
        end
    end

    ParseResult(argvals, defaults, errors)
end

"""
    update_defaults(result::ParseResult, defaults::Dict{String,Any})::ParseResult

Create a new [`ParseResult`](@ref) of which option values are updated by new default values.

`ParseResult` actually remembers the command line arguments and the default values which
were originally defined by [`CliOptionSpec`](@ref). This function firstly updates (merges)
the default values stored in `result` using `defaults`, secondly resolves final option
values, and finally creates and returns a new `ParseResult`.

This function is useful for a program which uses multiple sources of default values.
For example, if you want to resolve option values in the following order:

1. Option values specified as command line argument
2. Option values read from a config file
3. Hard coded default value

you can use this function as below:

```jldoctest
using CliOptions

# Firstly parse arguments normally
spec = CliOptionSpec(
    Option("--config-file"),
    Option("-x"; default = "foo"),
)
args = split("--config-file /path/to/config/file")
options = parse_args(spec, args)
println(options.x)  # We see hard-coded default value

# Let's pretend we loaded a config file and update defaults with it
config = Dict("x" => "bar")
options = update_defaults(options, config)
println(options.x)  # Now we see the default value in the config file

# If the option was specified in command line arguments, update_defaults has no effect
args = split("--config-file /path/to/config/file -x baz")
options = parse_args(spec, args)
options = update_defaults(options, config)
println(options.x)  # We see the value specified in the command line arguments

# output

foo
bar
baz
```
"""
function update_defaults(result::ParseResult, defaults::AbstractDict)::ParseResult
    new_defaults = copy(result._defaults)
    for k in keys(new_defaults)
        if haskey(defaults, k)
            new_defaults[k] = (defaults[k], new_defaults[k][2])
        end
    end
    ParseResult(result._argvals, new_defaults, result._errors)
end

# Internals
function _stringify(e::Exception)
    buf = IOBuffer()
    showerror(buf, e)
    String(take!(buf))
end

encode(s) = replace(replace(s, r"^(--|-|/)" => ""), r"[^0-9a-zA-Z]" => "_")

_to_placeholder(name::String) = uppercase(encode(name))
_to_placeholder(names::Tuple{String}) = uppercase(encode(names[1]))
_to_placeholder(names::Tuple{String,String}) = begin
    uppercase(encode(2 ≤ length(names) ? names[2] : names[1]))
end

function _get_duplicates(iterables::T...) where T
    duplicates = eltype(T)[]
    elements = collect(Iterators.flatten(iterables))
    for i = 1:length(elements)
        for j = i+1:length(elements)
            if elements[i] == elements[j]
                push!(duplicates, elements[i])
            end
        end
    end
    duplicates
end

function foreach_options(f, option::AbstractOption)
    if option isa AbstractOptionGroup
        for o in option.options
            foreach_options(f, o)
        end
    end
    f(option)
end

_exit = Base.exit

function _mock_exit_function(mock)  # Testing utility
    global _exit
    backup = _exit
    _exit = mock
    return _exit
end

function _mock_exit_function(f, mock)  # Testing utility
    backup = _mock_exit_function(mock)
    try
        f()
    finally
        _mock_exit_function(backup)
    end
end

function _normalize_args(args)
    normalized = String[]
    for i = 1:length(args)
        if !startswith(args[i], '-')
            push!(normalized, args[i])
        elseif startswith(args[i], "--")
            kv = split(args[i], '=')
            if length(kv) == 1
                push!(normalized, args[i])  # --foo-bar
            elseif length(kv) == 2
                push!(normalized, kv[1], kv[2])  # --foo-bar=baz
            else
                throw(CliOptionError("Unrecognizable option string: \"$(args[i])\""))
            end
        elseif startswith(args[i], '-')
            append!(normalized, ["-$c" for c in args[i][2:end]])  # -abc ==> -a -b -c
        end
    end
    return normalized
end

function _check_option_name(name)
    if "" == name
        return :empty  # An empty string
    elseif name[1] != '-'
        return :no_dash  # Not starting with a dash
    elseif name == "--"
        return :double_dash  # It's double dash
    elseif match(r"^-[^-]", name) === nothing && match(r"^--[^-]", name) === nothing
        return :invalid  # At least invalid as a name of an option
    end

    if tryparse(Float64, name) !== nothing
        return :negative  # It can be a negative number or a name of an option
    end
    return :valid  # It is a name of an option
end

function _validate_option_names(T, name_lists...)
    article(T) = occursin("$T"[1], "AEIOUaeiou") ? "an" : "a"
    names = collect(Iterators.flatten(name_lists))
    if length(names) == 0
        throw(ArgumentError("At least one name must be supplied for $(article(T)) $T"))
    end
    duplicates = _get_duplicates(names)
    if 1 ≤ length(duplicates)
        throw(ArgumentError("Duplicate names for $(article(T)) $T found: " *
                            join(duplicates, ", ")))
    end
    for name in names
        result = _check_option_name(name)
        if result == :empty
            throw(ArgumentError("Name of $(article(T)) $T must not be empty"))
        elseif result == :no_dash
            throw(ArgumentError("Name of $(article(T)) $T must start with a dash:" *
                                " \"$name\""))
        elseif result in (:double_dash, :invalid)
            throw(ArgumentError("Invalid name for $T: \"$name\""))
        end
    end
end

function _parse(T, optval::AbstractString, requirement::Any; optname = "")
    parsed_value::Union{Nothing,T} = nothing
    try
        # Use `parse` if available, or use constructor of the type
        if applicable(parse, T, optval)
            parsed_value = parse(T, optval)
        else
            parsed_value = T(optval)
        end
    catch ex
        # Generate message expressing the error encountered
        if :msg in fieldnames(typeof(ex))
            reason = ex.msg
        else
            reason = split(_stringify(ex), '\n')[1]
        end

        # Throw exception with formatted message
        buf = IOBuffer()
        print(buf, "Unparsable ")
        print(buf, optname == "" ? "positional argument" : "value for $optname")
        print(buf, " of type $T: ")
        print(buf, "\"$optval\" ($reason)")
        msg = String(take!(buf))
        throw(CliOptionError(msg))
    end

    # Validate the parsed result
    reason = ""
    if requirement isa Function
        rv = requirement(parsed_value)
        if rv == false || (rv isa String && rv != "")
            reason = rv isa Bool ? "validation failed" : rv
        end
    elseif requirement isa Regex
        if match(requirement, optval) === nothing
            reason = "must match for $(requirement)"
        end
    elseif requirement !== nothing
        if !any(x == parsed_value for x in requirement)
            reason = "must be one of " * join([isa(s, Regex) ? "$s" : "\"$s\""
                                               for s in requirement],
                                              ", ", " or ")
        end
    end

    # Throw if validation failed
    if reason != ""
        buf = IOBuffer()
        print(buf, "Invalid ")
        print(buf, "value for $optname")  #TODO: in case of positional argument
        print(buf, T == String ? ": " : " of type $T: ")
        print(buf, "\"$optval\" ($reason)")
        msg = String(take!(buf))
        throw(CliOptionError(msg))
    end

    # Return validated value
    parsed_value
end

const _usage_indent = 27
function print_description(io, names, val, help)
    heading = join(names, ", ") * (val != "" ? " $val" : "")
    print(io, repeat(" ", 4) * heading)
    if _usage_indent ≤ length(heading) + 4
        println(io)
        println(io, repeat(" ", _usage_indent) * help)
    else
        println(io, repeat(" ", _usage_indent - 4 - length(heading)) * help)
    end
    println(io)
end


export CliOptionSpec,
       Option,
       FlagOption,
       CounterOption,
       HelpOption,
       Positional,
       OptionGroup,
       MutexGroup,
       update_defaults,
       parse_args,
       print_usage,
       CliOptionError

end # module
