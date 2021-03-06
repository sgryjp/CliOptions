using Test
using CliOptions

include("testutils.jl")


@testset "Internal utilities" begin

    @testset "_validate_option_names(); $(v[1])" for v in [
        # valid form
        ("short form", Option, ["-a"], false, ""),
        ("long form", Option, ["--foo-bar"], false, ""),

        # article in an error message
        ("article for Option", Option, ["a"], true, "an Option"),
        ("article for FlagOption", FlagOption, ["a"], true, "a FlagOption"),
        ("article for CounterOption", CounterOption,[ "a"], true, "a CounterOption"),

        # reason
        ("nameless", Option, String[], true, "At least one name"),
        ("empty", Option, [""], true, "must not be empty"),
        ("starting with non-dash", Option, ["a"], true, "must start with a dash"),
        ("double dash only", Option, ["--"], true, "Invalid name"),
    ]
        _, T, names, should_fail, substr = v
        ok = false
        try
            CliOptions._validate_option_names(T, names)
            ok = true
        catch ex
            @test ex isa ArgumentError
            if 1 ≤ length(names)
                @test occursin(names[1], ex.msg)
            end
            @test occursin(substr, ex.msg)
        end
        @test ok == !should_fail
    end

    @testset "encoding($(v[1]))" for v in [
        ("f", "f"),
        ("-f", "f"),
        ("/f", "f"),
        ("--f", "f"),
        ("--foo-bar", "foo_bar"),
        ("-foo bar", "foo_bar"),
    ]
        input, expected = v
        @test CliOptions.encode(input) == expected
    end

    @testset "_get_duplicates($(v[1]), $(v[2]))" for v in [
        ([1, 1], [], [1]),
        ([1, 2], [], []),
        ([1, 2], [3, 4], []),
        ([1, 1], [3, 4], [1]),
        ([1, 2], [2, 4], [2]),
        ([1, 2], [3, 3], [3]),
    ]
        iter1, iter2, expected = v
        if length(iter2) == 0
            @assert CliOptions._get_duplicates(iter1) == expected
        else
            @assert CliOptions._get_duplicates(iter1, iter2) == expected
        end
    end

    @testset "foreach_options; $(v[2])" for v in [
        (
            OptionGroup(
                FlagOption("-a"),
                MutexGroup(
                    CounterOption("-b"),
                    Option("-c")
                ),
                Positional("x"),
                OptionGroup(
                    Positional("y"),
                    Positional("z"),
                ),
            ),
            "-a;-b;-c;x;y;z;",
        ),
    ]
        root, trace = v
        buf = IOBuffer()
        CliOptions.foreach_options(root) do o
            if !isa(o, CliOptions.AbstractOptionGroup)
                print(buf, o.names[1])
                print(buf, ';')
            end
        end
        @test trace == String(take!(buf))
    end

    @testset "_normalize_args(); $(v[1])" for v in [
        (["ab"], ["ab"]),
        (["-ab"], ["-a", "-b"]),
        (["--ab"], ["--ab"]),
        (["--ab="], ["--ab", ""]),
        (["--ab=c"], ["--ab", "c"]),
        (["--ab=c="], CliOptionError),
    ]
        args, expected = v
        if expected isa Type
            @test_throws expected CliOptions._normalize_args(args)
        else
            normalized = CliOptions._normalize_args(args)
            @test normalized == expected
        end
    end

    @testset "CliOptionError; showerror" begin
        let ex = CliOptionError("foo bar")
            buf = IOBuffer()
            showerror(buf, ex)
            msg = String(take!(buf))
            @test occursin("foo bar", msg)
        end
    end

end
