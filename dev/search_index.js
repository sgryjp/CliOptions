var documenterSearchIndex = {"docs":
[{"location":"#CliOptions.jl:-Parsing-command-line-options-1","page":"Home","title":"CliOptions.jl: Parsing command line options","text":"","category":"section"},{"location":"#","page":"Home","title":"Home","text":"🚧UNDER HEAVY CONSTRUCTION🚧","category":"page"},{"location":"#","page":"Home","title":"Home","text":"CliOptions.jl is a library for parsing command line options. There is no need to learn DSL (domain specific language) to use this library. The most basic steps to use this library is:","category":"page"},{"location":"#","page":"Home","title":"Home","text":"Define specification of the command line options\nParse command line arguments\nOptionally, merge the result with other option values (e.g.: environment variable or configuration files)\nUse the resolved option values","category":"page"},{"location":"#Table-of-Contents-1","page":"Home","title":"Table of Contents","text":"","category":"section"},{"location":"#","page":"Home","title":"Home","text":"","category":"page"},{"location":"#Index-1","page":"Home","title":"Index","text":"","category":"section"},{"location":"#","page":"Home","title":"Home","text":"","category":"page"},{"location":"reference/#API-Reference-1","page":"API Reference","title":"API Reference","text":"","category":"section"},{"location":"reference/#","page":"API Reference","title":"API Reference","text":"Pages = [\"reference.md\"]","category":"page"},{"location":"reference/#Defining-Command-Line-Option-Spec.-1","page":"API Reference","title":"Defining Command Line Option Spec.","text":"","category":"section"},{"location":"reference/#CliOptionSpec-1","page":"API Reference","title":"CliOptionSpec","text":"","category":"section"},{"location":"reference/#","page":"API Reference","title":"API Reference","text":"CliOptionSpec","category":"page"},{"location":"reference/#CliOptions.CliOptionSpec","page":"API Reference","title":"CliOptions.CliOptionSpec","text":"CliOptionSpec(options::AbstractOption...;\n              program = PROGRAM_FILE,\n              use_double_dash = true,\n              onhelp = 0,\n              onerror = 1)\n\nA type representing a command line option specification.\n\nprogram parameter is used for the program name which appears in help (usage) message. If omitted, Base.PROGRAM_FILE will be used.\n\nIf use_double_dash parameters is true, no argument after double dash (--) will be recognized as an option. In this case, the double dash itself will not parsed as an option nor a positional argument. Note that only the first double dash is treated specially so double dashes which appeares after it will be recognized as positional arguments. This is especially useful for programs which launches another program using command line arguments given to itself.\n\nonhelp parameter controls what to do if a HelpOption was used. It can be either:\n\nAn Integer\nThe running program will print help message and exit using it as the status code.\nnothing\nNothing happens. In this case, the HelpOption is treated just like a FlagOption so you can examine whether it was used or not by examining ParseResult using its name.\nA function which takes no arguments\nDo whatever you want in the function.\n\nThe default value is 0.\n\nonerror parameter controls the action when an error was detected on parsing arguments. Available choices are:\n\nAn Integer\nThe running program will print an error message along with a help message and exit with the status code.\nnothing\nIgnore errors. Note that error messages are stored in _errors field of the returning ParseResult so you can examine them later.\nA function which takes an error message\nExample 1) onerror = (msg) -> (@warn msg) ... Warn the error but continue processing\nExample 2) onerror = error ... Throw ErrorException using Base.exit, instead of exiting\n\nThe default value is 1.\n\nExample: Using a function for onhelp parameter\n\nusing CliOptions\n\nspec = CliOptionSpec(\n    HelpOption(),\n    onhelp = () -> begin\n        print_usage(spec, verbose = false)\n        # exit(42)  # Use exit() to let the program exit inside parse_args()\n    end,\n    program = \"onhelptest.jl\"\n)\noptions = parse_args(spec, [\"-h\"])  # The program does not exit here\nprintln(options.help)\n\n# output\n\nUsage: onhelptest.jl [-h]\ntrue\n\nExample: Using a function for onerror parameter\n\nusing CliOptions\n\nspec = CliOptionSpec(\n    Option(\"--required-argument\"),\n    onerror = (msg) -> println(\"Warning: $msg\"),\n)\noptions = parse_args(spec, String[])\nprintln(repr(options.required_argument))\n\n# output\n\nWarning: Option \"--required-argument\" must be specified\nmissing\n\n\n\n\n\n","category":"type"},{"location":"reference/#Option-1","page":"API Reference","title":"Option","text":"","category":"section"},{"location":"reference/#","page":"API Reference","title":"API Reference","text":"Option","category":"page"},{"location":"reference/#CliOptions.Option","page":"API Reference","title":"CliOptions.Option","text":"Option([type=String,] primary_name::String, secondary_name::String = \"\";\n       default = missing, until = nothing, requirement = nothing, help = \"\")\n\nType representing a command line option whose value is a following argument. Two forms of option notations are supported:\n\nShort form (e.g.: -n 42)\nStarting with a dash, one character follows it\nA following command line argument will be the option's value\nLong form (e.g.: --foo-bar)\nStarting with two dash, dash-separated words follow them\nValue can be specified as one of the two forms below:\n--foo-bar value; a following command line argument becomes the option's value\n--foo-bar=value; characters after an equal sign following the option name becomes the option's value\n\nAn Option can have two names. primary_name is typically a short form notation and is also used to express the option in a usage message or error messages. secondary_name is typically a long form notation and is also used to generate a value name in a usage message. For example, if names of an option are -n and --foo-bar, it will appear in a usage message as -n FOO_BAR. If you want to define an option which have only a long form notation, specify it as primary_name and omit secondary_name.\n\nIf type parameter is set, option values will be converted to the type inside parse_args and will be stored in returned ParseResult.\n\ndefault parameter is used when parse_args does not see the option in the given command line arguments. If a value other than missing was specified, it will be the option's value. If it's missing, absense of the option is considered as an error; in other word, the option becomes a required option. The default value of default parameter is missing.\n\nIf until parameter is specified, following arguments will be collected into a vector to be the option's value until an argument which is or one of the until parameter appears. In this case, type of the option's value will be Vector{T} where T is the type specified with type parameter. until parameter can be a string, a vector or tuple of strings, or nothing. Default value is nothing; no collection will be done.\n\nrequirement determines how to validate the option's value. If the option's value does not meet the requirement, it's considered an error. requirement can be one of:\n\nnothing\nAny value will be accepted\nA list of acceptable values\nArguments which matches one of the values will be accepted\nAny iterable can be used to specify acceptable values\nArguments will be converted to the specified type and then compared to each element of the list using function ==\nA Regex\nArguments which matches the regular expression will be accepted\nPattern matching will be done for unprocessed input string, not type converted one\nA custom validator function\nIt validates command line arguments one by one\nIt can return a Bool which indicates whether a given argument is acceptable or not\nIt also can return a String describing why a given command line argument is NOT acceptable, or an empty String if it is acceptable\n\nIf you want an option which does not take a command line argument as its value, see FlagOption and CounterOption\n\n\n\n\n\n","category":"type"},{"location":"reference/#FlagOption-1","page":"API Reference","title":"FlagOption","text":"","category":"section"},{"location":"reference/#","page":"API Reference","title":"API Reference","text":"FlagOption","category":"page"},{"location":"reference/#CliOptions.FlagOption","page":"API Reference","title":"CliOptions.FlagOption","text":"FlagOption(primary_name::String, secondary_name::String = \"\";\n           negators::Union{String,Vector{String}} = String[],\n           help = \"\",\n           negator_help = \"\")\n\nFlagOption represents a so-called \"flag\" command line option. An option of this type takes no value and whether it was specified becomes a boolean value.\n\n\n\n\n\n","category":"type"},{"location":"reference/#CounterOption-1","page":"API Reference","title":"CounterOption","text":"","category":"section"},{"location":"reference/#","page":"API Reference","title":"API Reference","text":"CounterOption","category":"page"},{"location":"reference/#CliOptions.CounterOption","page":"API Reference","title":"CliOptions.CounterOption","text":"CounterOption([type=Int,] primary_name::String, secondary_name::String = \"\";\n              decrementers::Union{String,Vector{String}} = String[],\n              default::Signed = 0,\n              help::String = \"\",\n              decrementer_help = \"\")\n\nA type represents a flag-like command line option. Total number of times a CounterOption was specified becomes the option's value.\n\n\n\n\n\n","category":"type"},{"location":"reference/#Positional-1","page":"API Reference","title":"Positional","text":"","category":"section"},{"location":"reference/#","page":"API Reference","title":"API Reference","text":"Positional","category":"page"},{"location":"reference/#CliOptions.Positional","page":"API Reference","title":"CliOptions.Positional","text":"Positional([type=String,] singular_name, plural_name = \"\";\n           multiple = false, requirement = nothing,\n           default = missing, help = \"\")\n\nPositional represents a command line argument which are not an option name nor an option value.\n\nrequirement determines how to validate positional arguments. See explanation of Option for more detail.\n\n\n\n\n\n","category":"type"},{"location":"reference/#HelpOption-1","page":"API Reference","title":"HelpOption","text":"","category":"section"},{"location":"reference/#","page":"API Reference","title":"API Reference","text":"HelpOption","category":"page"},{"location":"reference/#CliOptions.HelpOption","page":"API Reference","title":"CliOptions.HelpOption","text":"HelpOption(names = (\"-h\", \"--help\"); [help::String])\n\nOptions for printing help (usage) message.\n\nThe default value of names are -h and --help. If you do not like to have -h for printing help message, just give --help for names parameter (i.e.: HelpOption(\"--help\"; ...)).\n\nThe default behavior for a help option is printing help message and exiting. If you do not like this behavior, use onhelp parameter on constructing CliOptionSpec.\n\n\n\n\n\n","category":"type"},{"location":"reference/#OptionGroup-1","page":"API Reference","title":"OptionGroup","text":"","category":"section"},{"location":"reference/#","page":"API Reference","title":"API Reference","text":"OptionGroup","category":"page"},{"location":"reference/#CliOptions.OptionGroup","page":"API Reference","title":"CliOptions.OptionGroup","text":"OptionGroup(options::AbstractOption...; name::String = \"\")\n\nOptionGroup contains one or more AbstractOptions and accepts command line arguments if one of the options is accepted. In other word, this is an OR operator for AbstractOptions.\n\n\n\n\n\n","category":"type"},{"location":"reference/#MutexGroup-1","page":"API Reference","title":"MutexGroup","text":"","category":"section"},{"location":"reference/#","page":"API Reference","title":"API Reference","text":"MutexGroup","category":"page"},{"location":"reference/#CliOptions.MutexGroup","page":"API Reference","title":"CliOptions.MutexGroup","text":"MutexGroup(options::AbstractOption...; name::String = \"\")\n\nMutexGroup contains one or more AbstractOptions and accepts command line arguments only if exactly one of the options was accepted.\n\n\n\n\n\n","category":"type"},{"location":"reference/#Parsing-Arguments-1","page":"API Reference","title":"Parsing Arguments","text":"","category":"section"},{"location":"reference/#parse_args-1","page":"API Reference","title":"parse_args","text":"","category":"section"},{"location":"reference/#","page":"API Reference","title":"API Reference","text":"parse_args","category":"page"},{"location":"reference/#CliOptions.parse_args","page":"API Reference","title":"CliOptions.parse_args","text":"parse_args(spec::CliOptionSpec, args = ARGS)\n\nParse args according to the spec.\n\nspec is an instance of CliOptionSpec which defines how to parse command line arguments. It is constructed with one or more concrete subtypes of AbstractOptions. See document of AbstractOption for full list of its subtypes.\n\nargs is the command line arguments to be parsed. If omitted, Base.ARGS – the command line arguments passed to the Julia script – will be parsed.\n\nThis function returns a ParseResult after parsing. It is basically a Dict-like object holding the values of options.\n\nusing CliOptions\n\nspec = CliOptionSpec(\n    Option(Int, \"-n\", \"--num-workers\"),\n    FlagOption(\"-i\", \"--ignore-case\"; negators = \"--case-sensitive\"),\n    Positional(\"root\"),\n    Positional(\"pattern\", \"patterns\"; multiple = true);\n    program = \"myfind\"\n)\n\nargs = parse_args(spec, split(\"-n 3 -i /var/log *.log\", \" \"))\nprintln(\"num_workers: \", args.num_workers)\nprintln(\"ignore_case: \", args.ignore_case)\nprintln(\"root: \", args.root)\nprintln(\"patterns: \", args.patterns)\n\n# output\n\nnum_workers: 3\nignore_case: true\nroot: /var/log\npatterns: [\"*.log\"]\n\n\n\n\n\n","category":"function"},{"location":"reference/#Merging-withOption-Values-1","page":"API Reference","title":"Merging withOption Values","text":"","category":"section"},{"location":"reference/#update_defaults-1","page":"API Reference","title":"update_defaults","text":"","category":"section"},{"location":"reference/#","page":"API Reference","title":"API Reference","text":"update_defaults","category":"page"},{"location":"reference/#CliOptions.update_defaults","page":"API Reference","title":"CliOptions.update_defaults","text":"update_defaults(result::ParseResult, defaults::Dict{String,Any})::ParseResult\n\nCreate a new ParseResult of which option values are updated by new default values.\n\nParseResult actually remembers the command line arguments and the default values which were originally defined by CliOptionSpec. This function firstly updates (merges) the default values stored in result using defaults, secondly resolves final option values, and finally creates and returns a new ParseResult.\n\nThis function is useful for a program which uses multiple sources of default values. For example, if you want to resolve option values in the following order:\n\nOption values specified as command line argument\nOption values read from a config file\nHard coded default value\n\nyou can use this function as below:\n\nusing CliOptions\n\n# Firstly parse arguments normally\nspec = CliOptionSpec(\n    Option(\"--config-file\"),\n    Option(\"-x\"; default = \"foo\"),\n)\nargs = split(\"--config-file /path/to/config/file\")\noptions = parse_args(spec, args)\nprintln(options.x)  # We see hard-coded default value\n\n# Let's pretend we loaded a config file and update defaults with it\nconfig = Dict(\"x\" => \"bar\")\noptions = update_defaults(options, config)\nprintln(options.x)  # Now we see the default value in the config file\n\n# If the option was specified in command line arguments, update_defaults has no effect\nargs = split(\"--config-file /path/to/config/file -x baz\")\noptions = parse_args(spec, args)\noptions = update_defaults(options, config)\nprintln(options.x)  # We see the value specified in the command line arguments\n\n# output\n\nfoo\nbar\nbaz\n\n\n\n\n\n","category":"function"},{"location":"reference/#Using-Parse-Result-1","page":"API Reference","title":"Using Parse Result","text":"","category":"section"},{"location":"reference/#ParseResult-1","page":"API Reference","title":"ParseResult","text":"","category":"section"},{"location":"reference/#","page":"API Reference","title":"API Reference","text":"CliOptions.ParseResult","category":"page"},{"location":"reference/#CliOptions.ParseResult","page":"API Reference","title":"CliOptions.ParseResult","text":"CliOptions.ParseResult()\n\nDict-like object holding parsing result of command line options. The values can be accessed using either:\n\ndot notation (e.g.: result.num_workers)\nbracket notation (e.g.: result[\"num_workers\"])\n\nThis is the type parse_args function returns. If the function detected errors, it stores error messages into _errors field of this type. This may be useful if you let the program continue running on errors (see onerror parameter of CliOptionSpec).\n\n\n\n\n\n","category":"type"},{"location":"reference/#Misc.-1","page":"API Reference","title":"Misc.","text":"","category":"section"},{"location":"reference/#print_usage-1","page":"API Reference","title":"print_usage","text":"","category":"section"},{"location":"reference/#","page":"API Reference","title":"API Reference","text":"print_usage","category":"page"},{"location":"reference/#CliOptions.print_usage","page":"API Reference","title":"CliOptions.print_usage","text":"print_usage([io::IO], spec::CliOptionSpec; verbose = true)\n\nWrite usage (help) message to io. Set false to verbose if you want to print only the first line of the usage message. If io is omitted, message will be written stdout.\n\n\n\n\n\n","category":"function"},{"location":"reference/#CliOptionError-1","page":"API Reference","title":"CliOptionError","text":"","category":"section"},{"location":"reference/#","page":"API Reference","title":"API Reference","text":"CliOptionError","category":"page"},{"location":"reference/#CliOptions.CliOptionError","page":"API Reference","title":"CliOptions.CliOptionError","text":"CliOptionError(msg::String)\n\nAn error occurred inside CliOptions module. Message describing the error is available in the msg field.\n\n\n\n\n\n","category":"type"},{"location":"reference/#AbstractOption-1","page":"API Reference","title":"AbstractOption","text":"","category":"section"},{"location":"reference/#","page":"API Reference","title":"API Reference","text":"CliOptions.AbstractOption","category":"page"},{"location":"reference/#CliOptions.AbstractOption","page":"API Reference","title":"CliOptions.AbstractOption","text":"CliOptions.AbstractOption\n\nAbstract supertype representing a command line option. Concrete subtypes are:\n\nOption ... an option which takes a following argument as its value\nFlagOption ... an option of which existence becomes its boolean value\nCounterOption ... an option of which number of usage becomes its integer value\nPositional ... an argument which is not an option\n\nNote that a group of options represented with AbstractOptionGroup is also an AbstractOption so it can be used to construct CliOptionSpec.\n\n\n\n\n\n","category":"type"},{"location":"reference/#AbstractOptionGroup-1","page":"API Reference","title":"AbstractOptionGroup","text":"","category":"section"},{"location":"reference/#","page":"API Reference","title":"API Reference","text":"CliOptions.AbstractOptionGroup","category":"page"},{"location":"reference/#CliOptions.AbstractOptionGroup","page":"API Reference","title":"CliOptions.AbstractOptionGroup","text":"CliOptions.AbstractOptionGroup\n\nAbstract type representing a group of command line options. Concrete subtypes are:\n\nOptionGroup\nMutexGroup\n\n\n\n\n\n","category":"type"}]
}
