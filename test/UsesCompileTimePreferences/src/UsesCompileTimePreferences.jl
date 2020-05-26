module UsesCompileTimePreferences

using CompileTimePreferences
export python, set_use_system_python

# Load our compile-time preferences
build_prefs = @load_compile_time_preferences()

# Use our build_prefs to make compile-time decisions
if get(build_prefs, "use_system_python", false)
    python() = "python"
else
    python() = "python_jll"
end

function __init__()
    # Always gotta do this so that our preferences don't get cleaned every few weeks
    @compile_time_init_helper()
end

end # module UsesCompileTimePreferences