# CompileTimePreferences.jl

Need an easy way to control code generation at compile-time?  Look no further:

```julia
using CompileTimePreferences

# Load our compile-time preferences
build_prefs = @load_compile_time_preferences()

# Use our build_prefs to make compile-time decisions
if get(build_prefs, "use_cuda", true)
    gpu(x) = blackmagic(x)
else
    gpu(x) = x
end

function __init__()
    # This is required for 
    @compile_time_init_helper()
end
```

Setting/getting compile-time preferences has never been easier!

```julia
function set_use_cuda(val::Bool)
    @modify_compile_time_preferences() do prefs
        prefs["use_cuda"] = val
    end
end
```

As long as you use `@load_compile_time_preferences()` at the top-level within your package, When your saved preferences are modified your package's precompilation file will be invalidated, and it will be re-compiled upon next usage!

### Why an `__init__()` helper?

`CompileTimePreferences.jl` uses the latest in Pkg scratch space technology, but unfortunately, because it uses the scratch space at compile time, the liveness tracking built-in to scratch spaces will think the preferences have been unused since the last time you compiled your package.  If this exceeds the generous margin of time (3 weeks, give or take) that `Pkg` allows a scrach space to exist untouched, it will be reaped.  This is clearly suboptimal, so we explicitly place a tracked usage within the `__init__()` method of your module.

Note that this still does mean that if you do not use your module at all for 3 weeks, it will be reaped.  If that's a problem for you, feel free to open an issue and we'll talk about making this use Artifacts instead of scratch spaces.