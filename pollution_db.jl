using DataFrames
using DuckDB
using Rembus

function create(db, city)
    DBInterface.execute(db, "CREATE TABLE $city AS SELECT * FROM 'data/$(city)_data.csv'")
    return "ok"
end

function query(db, city, element, threshold)
    return DataFrame(DBInterface.execute(
        db,
        "select date,no2,o3,station_name from $city where $element>$threshold"
    ))
end

db = DuckDB.DB()

#= Next steps for getting distributed:

# not mandatory for this demo, but useful for inspecting broker status
# and showing fault-tolerant features
@component "db"

# to share db handle with exposed methods: it is the first method argument
@shared db

@expose create

# for Julia clients
@expose query

=#
