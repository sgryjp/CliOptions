module CliOptions


"""
    CliOptionError(msg::String)

An error occurred inside CliOptions module.
"""
struct CliOptionError <: Exception
    msg::String
end

Base.showerror(io::IO, e::CliOptionError) = print(io, "CliOptionError: " * e.msg)

"""
    AbstractOption

A definition of a command line option. Defined subtypes of this type are:

- NamedOption
- Positional
"""
abstract type AbstractOption end

#
# NamedOption
#
struct NamedOption <: AbstractOption
    names::Vector{String}

    function NamedOption(names::String...)
        if length(names) == 0
            throw(ArgumentError("At least one name for a NamedOption must be specified"))
        end
        for name ∈ names
            if "" == name
                throw(ArgumentError("Name of a NamedOption must not be empty"))
            elseif name[1] != '-'
                throw(ArgumentError("Name of a NamedOption must start with a hyphen: " *
                                    name))
            end
        end
        new([n for n ∈ names])
    end
end

"""
    consume!(ctx, option, args, i)

Consumes zero or more arguments from `args` starting from index `i` according to the
`option`. This function returns a tuple of an index of next parsing position and a tuple of
key-value pairs. If the option is not matched for the argument, `(-1, nothing)` will be
returned.
"""
function consume!(ctx, o::NamedOption, args, i)
    @assert i ≤ length(args)
    if args[i] ∉ o.names
        return -1, nothing
    end
    if length(args) < i + 1
        throw(CliOptionError("A value is needed for option `" * args[i] * "`"))
    end

    # Get how many times this option was evaluated
    count::Int = get(ctx, o, -1)
    if count == -1
        ctx[o] = 0
    end

    # Skip if this node is already processed
    if 1 ≤ count
        return -1, nothing
    end
    ctx[o] += 1

    value = args[i + 1]
    i + 2, Tuple(encode(name) => value for name in o.names)
end

friendly_name(o::NamedOption) = "option"
primary_name(o::NamedOption) = o.names[1]

"""
    FlagOption

`FlagOption` represents a so-called "flag" command line option. An option of this type takes
no value and whether it was specified becomes a boolean value.
"""
struct FlagOption <: AbstractOption
    names::Vector{String}
    negators::Vector{String}

    function FlagOption(names::String...; negators::Vector{String}=String[])
        if length(names) == 0
            throw(ArgumentError("At least one name for a FlagOption must be specified"))
        end
        for name in unique(vcat(collect(names), negators))
            if match(r"^-[^-]", name) === nothing && match(r"^--[^-]", name) === nothing
                if name == ""
                    throw(ArgumentError("Name of a FlagOption must not be empty"))
                elseif match(r"^[^-]", name) !== nothing
                    throw(ArgumentError("Name of a FlagOption must start with a hyphen: " *
                                        name))
                else
                    throw(ArgumentError("Invalid name for FlagOption: " * name))
                end
            end
        end
        new([n for n ∈ names], [n for n ∈ negators])
    end
end

function consume!(ctx, o::FlagOption, args, i)
    @assert i ≤ length(args)

    if startswith(args[i], "--")
        if args[i] ∈ o.names
            value = true
        elseif args[i] ∈ o.negators
            value = false
        else
            return -1, nothing
        end
    elseif startswith(args[i], "-")
        @assert length(args[i]) == 2  # Splitting -abc to -a, -b, -c is done by parse_args()
        if args[i] ∈ o.names
            value = true
        elseif args[i] ∈ o.negators
            value = false
        else
            return -1, nothing
        end
    else
        return -1, nothing
    end

    # Update counter
    count::Int = get(ctx, o, -1)
    if count == -1
        ctx[o] = 0
    else
        ctx[o] = count + 1
    end

    # Construct parsed values
    values = Vector{Pair{String,Bool}}()
    push!(values, [encode(name) => value for name in o.names]...)
    push!(values, [encode(name) => !value for name in o.negators]...)
    i + 1, Tuple(values)
end

friendly_name(o::FlagOption) = "flag option"
primary_name(o::FlagOption) = o.singular_name


"""
    Positional

`Positional` represents a command line argument which are not an option name nor an option
value.
"""
struct Positional <: AbstractOption
    names::Vector{String}
    multiple::Bool
    default::Any

    function Positional(singular_name, plural_name = "";
                        multiple=false,
                        default::Any=nothing)
        if singular_name == ""
            throw(ArgumentError("Name of a Positional must not be empty"))
        end
        if startswith(singular_name, '-')
            throw(ArgumentError("Name of a Positional must not start with a hyphen: " *
                                singular_name))
        end
        if startswith(plural_name, '-')
            throw(ArgumentError("Name of a Positional must not start with a hyphen: " *
                                plural_name))
        end

        if plural_name == ""
            return new([singular_name], multiple, default)
        else
            return new([singular_name, plural_name], multiple, default)
        end
    end
end

function consume!(ctx, o::Positional, args, i)
    @assert i ≤ length(args)
    @assert "" ∉ o.names

    # Get how many times this option was evaluated
    count::Int = get(ctx, o, -1)
    if count == -1
        ctx[o] = 0
    end

    # Skip if this node is already processed
    max_nvalues = o.multiple ? Inf : 1
    if max_nvalues ≤ count
        return -1, nothing
    end

    if o.multiple
        value = args[i:end]
        ctx[o] += length(value)
        next_index = i + length(value)
    else
        value = args[i]
        ctx[o] += 1
        next_index = i + 1
    end

    next_index, Tuple(encode(name) => value for name ∈ o.names)
end

friendly_name(o::Positional) = "positional argument"
primary_name(o::Positional) = o.names[1]


"""
    OptionGroup

`OptionGroup` contains one or more `AbstractOption`s and accepts command line arguments if
it sees one of the options. In other word, this is an OR operator for `AbstractOption`s.
"""
struct OptionGroup <: AbstractOption
    options

    OptionGroup(options::AbstractOption...) = new(options)
end

function consume!(ctx, o::OptionGroup, args, i)
    for option in o.options
        next_index, pairs = consume!(ctx, option, args, i)
        if 0 < next_index
            return next_index, pairs
        end
    end
    return -1, nothing
end


"""
    CliOptionSpec

`CliOptionSpec` defines how to parse command line options.
"""
struct CliOptionSpec
    root :: OptionGroup

    function CliOptionSpec(options::AbstractOption...)
        new(OptionGroup(options...))
    end
end


"""
    ParsedArguments

Dict-like object holding parsing result of command line options.
"""
struct ParsedArguments
    _dict
end

function Base.getindex(args::ParsedArguments, key)
    k = key isa Symbol ? String(key) : key
    getindex(args._dict, k)
end

function Base.propertynames(args::ParsedArguments, private = false)
    vcat([:_dict], [Symbol(k) for (k, v) ∈ getfield(args, :_dict)])
end

function Base.getproperty(args::ParsedArguments, name::String)
    Base.getproperty(args::ParsedArguments, Symbol(name))
end

function Base.getproperty(args::ParsedArguments, name::Symbol)
    if name == :_dict
        return getfield(args, :_dict)
    else
        return getfield(args, :_dict)[String(name)]
    end
end


"""
    parse_args(spec::CliOptionSpec, args=ARGS)

Parse command line options according to `spec`.

`args` is the command line arguments to be parsed. If omitted, this function parses
`Base.ARGS` which is an array of command line arguments passed to the Julia script.
"""
function parse_args(spec::CliOptionSpec, args = ARGS)
    dict = Dict{String,Any}()
    root::OptionGroup = spec.root
    ctx = Dict{AbstractOption,Int}()

    # Parse arguments
    i = 1
    while i ≤ length(args)
        next_index, pairs = consume!(ctx, root, args, i)
        if next_index < 0
            throw(CliOptionError("Unrecognized argument: " * args[i]))
        end

        for (k, v) ∈ pairs
            dict[k] = v
        end
        i = next_index
    end

    # Take care of omitted options  #TODO: Can this be done by init_context!(ctx, option)?
    for option ∈ (o for o ∈ root.options if o ∉ keys(ctx))
        if option isa FlagOption
            # Set implicit default boolean values
            foreach(k -> dict[encode(k)] = false, option.names)
            foreach(k -> dict[encode(k)] = true, option.negators)
        elseif option isa Positional
            if option.default === nothing
                msg = "A " * friendly_name(option) *
                      " \"" * primary_name(option) * "\" was not specified"
                throw(CliOptionError(msg))
            else
                foreach(k -> dict[encode(k)] = option.default, option.names)
            end
        end
    end

    ParsedArguments(dict)
end

# Internals
encode(s) = replace(replace(s, r"^(--|-|/)" => ""), r"[^0-9a-zA-Z]" => "_")
is_option(names) = any([startswith(name, '-') && 2 ≤ length(name) for name ∈ names])


export AbstractOption,
       CliOptionError,
       CliOptionSpec,
       FlagOption,
       NamedOption,
       OptionGroup,
       Positional,
       parse_args

end # module
