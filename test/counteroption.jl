using Test
using CliOptions

@testset "CounterOption()" begin
    @testset "ctor" begin
        @testset "names" begin
        @test_throws ArgumentError CounterOption()
            @test_throws ArgumentError CounterOption("")
            @test_throws ArgumentError CounterOption("a")
            @test_throws ArgumentError CounterOption("-")
            @test_throws ArgumentError CounterOption("--")
            @test_throws ArgumentError CounterOption("-a"; decrementers = [""])
            @test_throws ArgumentError CounterOption("-a"; decrementers = ["a"])
            @test_throws ArgumentError CounterOption("-a"; decrementers = ["-"])
            @test_throws ArgumentError CounterOption("-a"; decrementers = ["--"])
            #@test_throws ArgumentError CounterOption("-a"; decrementers = ["-a"])  #TODO
            @test_throws ArgumentError CounterOption(UInt8, "-a")

            option = CounterOption("-a")
            @test option.names == ["-a"]
            @test option.decrementers == String[]
        end

        @testset "decrementers" begin
            option = CounterOption("-a", "-b", decrementers = ["-c", "-d"])
            @test option.names == ["-a", "-b"]
            @test option.decrementers == ["-c", "-d"]
        end

        @testset "default" begin
            let result = CliOptions.ParsedArguments()
                @test_throws InexactError CounterOption(Int8, "-v", default = -129)
                CounterOption(Int8, "-v", default = -128)
                CounterOption(Int8, "-v", default = 127)
                @test_throws InexactError CounterOption(Int8, "-v", default = 128)
            end
        end
    end

    @testset "consume(::CounterOption)" begin
        option = CounterOption("-v", "--verbose")

        let result = CliOptions.ParsedArguments()
            @test_throws AssertionError CliOptions.consume!(result, option, String[], 1)
        end
        let result = CliOptions.ParsedArguments()
            # Splitting optchars are done by parse_args()
            @test_throws AssertionError CliOptions.consume!(result, option, ["-wv"], 1)
        end
        let result = CliOptions.ParsedArguments()
            next_index = CliOptions.consume!(result, option, ["v"], 1)
            @test next_index == -1
            @test sorted_keys(result._dict) == []
        end
        let result = CliOptions.ParsedArguments()
            next_index = CliOptions.consume!(result, option, ["-v"], 1)
            @test next_index == 2
            @test sorted_keys(result._dict) == ["v", "verbose"]
            @test result.v == 1
            @test result.verbose == 1
        end
        let result = CliOptions.ParsedArguments()
            next_index = CliOptions.consume!(result, option, ["--verbose"], 1)
            @test next_index == 2
            @test sorted_keys(result._dict) == ["v", "verbose"]
            @test result.v == 1
            @test result.verbose == 1
        end
    end

    @testset "consume(::CounterOption); decrementers" begin
        option = CounterOption("-v", decrementers = ["-q", "--quiet"])

        let result = CliOptions.ParsedArguments()
            @test_throws AssertionError CliOptions.consume!(result, option, String[], 1)
        end
        let result = CliOptions.ParsedArguments()
            # Splitting optchars are done by parse_args()
            @test_throws AssertionError CliOptions.consume!(result, option, ["-wv"], 1)
        end
        let result = CliOptions.ParsedArguments()
            next_index = CliOptions.consume!(result, option, ["v"], 1)
            @test next_index == -1
            @test sorted_keys(result._dict) == []
        end
        let result = CliOptions.ParsedArguments()
            next_index = CliOptions.consume!(result, option, ["-v"], 1)
            @test next_index == 2
            @test sorted_keys(result._dict) == ["v"]
            @test result.v == 1
        end
        let result = CliOptions.ParsedArguments()
            next_index = CliOptions.consume!(result, option, ["-q"], 1)
            @test next_index == 2
            @test sorted_keys(result._dict) == ["v"]
            @test result.v == -1
        end
        let result = CliOptions.ParsedArguments()
            next_index = CliOptions.consume!(result, option, ["--quiet"], 1)
            @test next_index == 2
            @test sorted_keys(result._dict) == ["v"]
            @test result.v == -1
        end
    end

    @testset "consume(::CounterOption); type" begin
        let result = CliOptions.ParsedArguments()
            option = CounterOption("-v")
            CliOptions.consume!(result, option, ["-v"], 1)
            @test typeof(result.v) == Int
        end
        let result = CliOptions.ParsedArguments()
            option = CounterOption(Int8, "-v")
            CliOptions.consume!(result, option, ["-v"], 1)
            @test typeof(result.v) == Int8
        end
        let result = CliOptions.ParsedArguments()
            option = CounterOption(Int128, "-v")
            CliOptions.consume!(result, option, ["-v"], 1)
            @test typeof(result.v) == Int128
        end
        let result = CliOptions.ParsedArguments()
            option = CounterOption(Int8, "-v")
            for _ in 1:127
                CliOptions.consume!(result, option, ["-v"], 1)
            end
            @test result.v == 127
            @test_throws InexactError CliOptions.consume!(result, option, ["-v"], 1)
        end
        let result = CliOptions.ParsedArguments()
            option = CounterOption(Int8, "-v"; decrementers = ["-q"])
            for _ in 1:128
                CliOptions.consume!(result, option, ["-q"], 1)
            end
            @test result.v == -128
            @test_throws InexactError CliOptions.consume!(result, option, ["-q"], 1)
        end
    end
end