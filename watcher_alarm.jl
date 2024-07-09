using ArgParse
using CSV
using DataFrames
using DuckDB
using Rembus

function command_line()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--element", "-e"
        help = "pollutant element"
        arg_type = String
        default = "no2"
        "--thr", "-t"
        help = "a value above threshold value generate an alarm"
        arg_type = Float64
        default = 150.0
    end
    return parse_args(s)
end

function set_thr(args, value)
    old_value = args["thr"]
    args["thr"] = value
    return old_value
end

function pollution(args, fn, content)
    @info "pollution from: $fn"
    #thr = parse(Float64, ARGS[1])
    thr = args["thr"]
    el = args["element"]
    df = CSV.read(content, DataFrame)

    db = DuckDB.DB()
    DuckDB.register_data_frame(db, df, "df")
    alarms = DataFrame(
        DBInterface.execute(db, "SELECT date, station_name, no2, o3 FROM df WHERE $el>$thr")
    )

    @info "alarms: $alarms"

    for alarm in eachrow(alarms)
        @publish alarm(
            Dict(
                "ts" => alarm.Date,
                "station" => alarm.station_name,
                "no2" => alarm.NO2,
                "o3" => alarm.O3
            )
        )
    end
end

args = command_line()

@shared args
@subscribe pollution

@expose set_thr

@forever
