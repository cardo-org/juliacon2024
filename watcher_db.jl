using CSV
using DataFrames
using DuckDB
using Rembus

function pollution(db, fn, content)
    tablename = replace(basename(fn), r"_.*$" => "")
    @info "data from $tablename"
    df = CSV.read(content, DataFrame)
    DuckDB.register_data_frame(db, df, tablename)
end

function query(db, city, pollutant, thr)
    return DataFrame(
        DBInterface.execute(
            db,
            "SELECT date, station_name, no2, o3, pm10 from $city WHERE $pollutant>=$thr"
        )
    )
end

query2json(db, city, pollutant, thr) =
    [Dict(names(row) .=> values(row)) for row in eachrow(query(db, city, pollutant, thr))]

db = DuckDB.DB()

@component "duckdb"
@shared db
@subscribe pollution

@expose query
@expose query2json

@info "db ready"
@forever
