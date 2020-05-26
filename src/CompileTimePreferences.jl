module CompileTimePreferences
using Pkg, Pkg.Scratch, Pkg.TOML
import Base: UUID

export save_compile_time_preferences!, modify_compile_time_preferences!, @load_compile_time_preferences, @compile_time_init_helper

"""
    project_speciic_toml(uuid::UUID)

Given a UUID identifying a package, uses `Base.active_project()` to create a project-
specific scratch space for that package and returns a TOML file within that space.
"""
function project_speciic_toml(uuid::UUID)
    scratch_name = string("CompileTimePreferences-", string(Base.hash(Base.active_project()), base=16))
    return joinpath(get_scratch!(scratch_name, uuid), "Preferences.toml")
end

"""
    save_compile_time_preferences!(uuid::UUID, prefs::Dict)

Save preferences to a file within a project-specific scratch space.
"""
function save_compile_time_preferences!(uuid::UUID, prefs::Dict)
    toml_path = project_speciic_toml(uuid)
    open(toml_path, "w") do io
        TOML.print(io, prefs)
    end
end

"""
    modify_compile_time_preferences!(f::Function, uuid::UUID)

Calls the given function with a `prefs` dict, writes the modified dict back out
to disk once the user function returns.
"""
function modify_compile_time_preferences!(f::Function, uuid::UUID)
    prefs = Pkg.Types.parse_toml(project_speciic_toml(uuid); fakeit=true)
    f(prefs)
    save_compile_time_preferences!(uuid, prefs)
end

"""
    @load_compile_time_preferences()

Load the project-specific preferences previously saved through the function
`save_compile_time_preferences()`.  This macro should be used at top-level within your
package, and should always be accompanied by a `@compile_time_init_helper()` macro
in your package's `__init__()` method.  This macro returns a `Dict` containing the
preferences.
"""
macro load_compile_time_preferences()
    uuid = Pkg.Preferences.get_uuid_throw(__module__)
    return quote
        begin
            # The path to the TOML that contains our project-specific compile-time prefs
            toml_path = $(esc(project_speciic_toml))($(esc(uuid)))

            # Tell the compiler to invoke a recompile if that TOML file changes:
            Base.include_dependency(toml_path)

            # return the contents of that TOML file from this macro
            $(esc(Pkg.Types.parse_toml))(toml_path; fakeit=true)
        end
    end
end

"""
    @compile_time_init_helper()

This macro should be placed within the `__init__()` method of any package that uses
compile-time preferences.  This places an explicit usage upon the scratch space that
holds the serialized compile-time preferences, preventing the space from being GC'ed.
"""
macro compile_time_init_helper()
    uuid = Pkg.Preferences.get_uuid_throw(__module__)
    return quote
        $(esc(project_speciic_toml))($(esc(uuid)))
    end
end

end # module
