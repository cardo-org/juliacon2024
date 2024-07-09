using ArgParse
using Rembus

const DEFAULT_FOLDER = "src"

function command_line()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--watchdir"
        help = "source directory to watch"
        arg_type = String
        default = DEFAULT_FOLDER
        "--reset", "-r"
        help = "factory reset, clean up broker configuration"
        action = :store_true
        "--debug", "-d"
        help = "enable debug logs"
        action = :store_true
    end
    return parse_args(s)
end

function watch_task(pd, wdir)
    try
        @info "watch_task start, watchdir: [$wdir]"

        router = Rembus.get_router()
        prev_paths = []
        while true
            files = readdir(wdir)
            sleep(0.2)
            for fn in files
                fpath = joinpath(wdir, fn)
                if fn === "foo"
                    rm(fpath, force=true)
                    error("harakiri")
                end

                try
                    content = read(fpath)
                    publish(router, "pollution", [basename(fn), content])
                    rm(fpath, force=true)
                catch e
                    @info "error: $e, retrying ..."
                end
            end
        end
    catch e
        @error "watch_task: $e"
        showerror(stdout, e, stacktrace())
    end
    @info "watch_task done"
end

args = command_line()
sv = caronte(wait=false, args=merge(args, Dict("http" => 9000)))
startup(process(watch_task, args=(args["watchdir"],), restart=:permanent))
