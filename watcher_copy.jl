using ArgParse
using Rembus

const DEFAULT_FOLDER = "dst"

function command_line()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--dir", "-d"
        help = "destination directory to copy the files"
        arg_type = String
        default = DEFAULT_FOLDER
    end
    return parse_args(s)
end

function pollution(args, fn, content)
    @info "[$fn]: uploading to $(args["dir"])"
    target_fn = joinpath(args["dir"], fn)
    write(target_fn, content)
end

args = command_line()

@shared args
@subscribe pollution
@info "backup service up and running"
@forever
