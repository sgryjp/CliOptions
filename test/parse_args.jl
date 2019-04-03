using Test
using CliOptions

@testset "parse_args()" begin
    @testset "Mixed options" begin
        spec = CliOptionSpec(
            NamedOption("-n", "--num-workers"),
            FlagOption("-i", "--ignore-case", negators = ["--case-sensitive"]),
            Positional("filename"),
        )
        args = parse_args(spec, ["-n", "3", "test.db"])
        @test args isa CliOptions.ParsedArguments
        @test args._dict["n"] == "3"
        @test args._dict["num_workers"] == "3"
        @test args._dict["ignore_case"] == false
        @test args._dict["case_sensitive"] == true
        @test args._dict["filename"] == "test.db"
        @test args["n"] == "3"
        @test args["num_workers"] == "3"
        @test args["ignore_case"] == false
        @test args["case_sensitive"] == true
        @test args["filename"] == "test.db"
        @test args.n == "3"
        @test args.num_workers == "3"
        @test args.ignore_case == false
        @test args.case_sensitive == true
        @test args.filename == "test.db"

        @test_throws CliOptionError parse_args(spec, ["test.db", "test.txt"])
    end

    @testset "FlagOption" begin
        spec = CliOptionSpec(FlagOption("-a"; negators = ["-b"]), )
        args = parse_args(spec, split("-a", " "))
        @test args.a == true
        @test args.b == false

        args = parse_args(spec, split("-b", ' '))
        @test args.a == false
        @test args.b == true

        spec = CliOptionSpec(FlagOption("-a"; negators = ["-b"]), FlagOption("-c"))
        args = parse_args(spec, ["-c"])
        @test args.c == true
        @test args.a == false
        @test args.b == true
    end

    @testset "Positional" begin
        @testset "single, required" begin
            spec = CliOptionSpec(
                Positional("file", "files"),
            )
            @test_throws CliOptionError parse_args(spec, String[])
            args = parse_args(spec, ["a"])
            @test args.file == "a"
            @test args.files == "a"
            @test_throws CliOptionError parse_args(spec, ["a", "b"])
        end

        @testset "single, omittable" begin
            spec = CliOptionSpec(
                Positional("file", "files"; default = "foo.txt"),
            )
            args = parse_args(spec, String[])
            @test args.file == "foo.txt"
            @test args.files == "foo.txt"
            @test_throws CliOptionError parse_args(spec, ["a", "b"])
            args = parse_args(spec, ["a"])
            @test args.file == "a"
            @test args.files == "a"
            @test_throws CliOptionError parse_args(spec, ["a", "b"])
        end

        @testset "multiple, required" begin
            spec = CliOptionSpec(
                Positional("file", "files"; multiple = true),
            )
            @test_throws CliOptionError parse_args(spec, String[])
            args = parse_args(spec, ["a"])
            @test args.file == ["a"]
            @test args.files == ["a"]
            args = parse_args(spec, ["a", "-b"])
            @test args.file == ["a", "-b"]
            @test args.files == ["a", "-b"]
        end

        @testset "multiple, omittable" begin
            spec = CliOptionSpec(
                Positional("file", "files"; multiple = true, default = ["foo.txt"]),
            )
            args = parse_args(spec, String[])
            @test args.file == ["foo.txt"]
            @test args.files == ["foo.txt"]
            args = parse_args(spec, ["a"])
            @test args.file == ["a"]
            @test args.files == ["a"]
            args = parse_args(spec, ["a", "-b"])
            @test args.file == ["a", "-b"]
            @test args.files == ["a", "-b"]
        end
    end
end
