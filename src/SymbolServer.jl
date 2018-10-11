module SymbolServer

export SymbolServerProcess
export getstore

using Serialization

mutable struct SymbolServerProcess
    process::Base.Process

    function SymbolServerProcess(environment=nothing)
        jl_cmd = joinpath(Sys.BINDIR, Base.julia_exename())
        client_process_script = joinpath(@__DIR__, "clientprocess", "clientprocess_main.jl")
        
        p = if environment===nothing
            open(Cmd(`$jl_cmd $client_process_script`), read=true, write=true)
        else
            open(Cmd(`$jl_cmd --project=$environment $client_process_script`, dir=environment), read=true, write=true)
        end
    
        return new(p)
    end
end

function request(server::SymbolServerProcess, message::Symbol, payload)
    serialize(server.process, (message, payload))
    ret_val = deserialize(server.process)
    return ret_val
end

# Public API

function getstore(server::SymbolServerProcess)
    if !isfile(joinpath(@__DIR__, "..", "store", "base.jstore"))
        store = load_base(server)
    else
        store = load(joinpath(@__DIR__, "..", "store", "base.jstore"))
    end

    pkgs_in_env = get_packages_in_env(server)
    for pkg in pkgs_in_env
        pkg_name = pkg[1]
        if !isfile(joinpath(@__DIR__, "..", "store", "$pkg_name.jstore"))
            pstore = load_module(server, pkg)
        else
            pstore = load(joinpath(@__DIR__, "..", "store", "$pkg_name.jstore"))            
        end
        store[pkg] = pstore
    end

    store[".importable_mods"] = collect_mods(store)

    return store
end

function Base.kill(s::SymbolServerProcess)
    kill(s.process)
end

function get_packages_in_env(server::SymbolServerProcess)
    status, payload = request(server, :get_packages_in_env, nothing)
    if status == :success
        return payload
    else
        error(payload)
    end
end

function load_base(server::SymbolServerProcess)
    status, payload = request(server, :load_base, nothing)
    if status == :success
        return payload
    else
        error(payload)
    end
end


function load_module(server::SymbolServerProcess, name::Symbol)
    status, payload = request(server, :load_module, name)
    if status == :success
        return payload
    else
        error(payload)
    end
end

end # module
