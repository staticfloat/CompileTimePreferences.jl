using Test, Pkg, Pkg.TOML, CompileTimePreferences, SHA
import Base: UUID

# Run certain tests within a temporary depot to ensure that 
function with_temp_depot(f::Function)
    mktempdir() do dir
        OLD_DEPOT_PATH = copy(Base.DEPOT_PATH)
        try
            # Run with only this new depot path
            empty!(Base.DEPOT_PATH)
            push!(Base.DEPOT_PATH, dir)

            f()
        catch e
            rethrow(e)
        finally
            # Reset everything back to the way it was before
            empty!(Base.DEPOT_PATH)
            append!(Base.DEPOT_PATH, OLD_DEPOT_PATH)
        end
    end
end

@testset "CompileTimePreferences" begin
    with_temp_depot() do
        # dev UCTP into our current temporary project created from Pkg.test()
        Pkg.develop(path=joinpath(@__DIR__, "UsesCompileTimePreferences"))

        uctp_uuid = UUID("ae19552e-0746-a912-f9bf-d305dc8664c6")
        # First, load it in a new Julia environment, show that it gets the default value:
        function get_python_choice()
            readchomp(setenv(
                `$(Base.julia_cmd()) --project=$(Base.active_project()) -e 'using UsesCompileTimePreferences; print(python())'`,
                "JULIA_DEPOT_PATH" => Pkg.depots1(),
            ))
        end
        @test get_python_choice() == "python_jll"

        # Ensure there's only one precompiled version right now and save its size
        uctp_comp_dir = joinpath(first(DEPOT_PATH), "compiled", "v$(VERSION.major).$(VERSION.minor)", "UsesCompileTimePreferences")
        @test length(readdir(uctp_comp_dir)) == 1
        old_hash = open(sha256, first(readdir(uctp_comp_dir; join=true)))
        
        # Now, set a preference to use system python
        function set_use_system_python(val::Bool)
            modify_compile_time_preferences!(uctp_uuid) do prefs
                prefs["use_system_python"] = val
            end
        end
        set_use_system_python(true)

        # Then run it again, and let's ensure the module was precompiled again
        @test get_python_choice() == "python"
        new_hash = open(sha256, first(readdir(uctp_comp_dir; join=true)))
        @test old_hash != new_hash

        # Run it one more time, ensure it was _not_ precompiled again
        @test get_python_choice() == "python"
        newer_hash = open(sha256, first(readdir(uctp_comp_dir; join=true)))
        @test new_hash == newer_hash

        # Let's ensure that we have a toml file now:
        toml_path = CompileTimePreferences.project_speciic_toml(uctp_uuid)
        @test isfile(toml_path)
        @test TOML.parsefile(toml_path)["use_system_python"] == true

        # Flip the value back again, ensure that the sentinel hash changes:
        set_use_system_python(false)
        @test isfile(toml_path)
        @test TOML.parsefile(toml_path)["use_system_python"] == false
        @test get_python_choice() == "python_jll"
    end
end