# Rembus samples

The following samples are execute with this alias:

```shell
alias j='julia --project=. --startup-file=no'
```

As first step start a caronte broker:

```shell
terminal> j caronte.jl
```

## RPC: Expose a DuckDB in-process database

Files:

- `pollution_db.jl`
- `pollution_rpc.jl`
- `data/ancona_data.csv`
- `data/athens_data.csv`
- `data/zaragoza_data.csv`

The data are from
[Air Quality Monitoring in European Cities](https://www.kaggle.com/datasets/yekenot/air-quality-monitoring-in-european-cities)
datasets published by Vladimir Demidov.

Download the datasets from kaggle and extract the 3 files in the `data` directory.

The `pollution_db.jl` manage a DuckDB database with a 2 API methods: `create` and
`query`:

`create` reads the file `"$city_data.csv"` and creates the pollution data table `$city`.

```julia
function create(db::DuckDB.DB, city)
    DBInterface.execute(
        db, 
        "CREATE TABLE $city AS SELECT * FROM 'data/$(city)_data.csv'"
    )
    return "ok"
end

```

`query` returns a dataframe that contains only the rows for which measured `elem` exceeds the `thr` value

```julia
function query(db::DuckDB.DB, city, elem, thr)
    return DataFrame(DBInterface.execute(
        db,
        "select date,no2,o3,station_name from $city where $elem>$thr"
    ))
end
```

for example:

```shell
console> j -i pollution_db.jl
julia> create(db, "ancona")
julia> df = query(db, "ancona", "no2", 150)
```

DuckDB in-process database is not available to external clients but with Rembus
is a matter of these three lines: 

```shell
julia> @shared db
julia> @expose create
julia> @expose query
```

The `@shared` macro declares the value `db` as a local object to be shared with
all exposed and subscribed methods:

When a component declares a shared value then all the subscribed and exposed methods
are called with the shared value as the first argument
and the following arguments corresponding to the `@rpc` or `@publish` arguments.

So, if a local method invocation is:

```julia
df = query(db, "ancona", "o3", 100)
```

and `@shared db` is used a remote invocation become:

```julia
df = @rpc query("ancona", "o3", 100)
```

Too see that in action, open another REPL or create a source file for interacting
with the pollution database:

```julia
using Rembus

# by default the broker url is ws://localhost:8000
# exactly where caronte is listening in this demo.
# If connecting to a remote broker use a url endpoint
# for the component.
#
# @component "ws://remote.host.org:8000"

@rpc create("zaragoza")
df = @rpc query("zaragoza", "no2", 150)
```

## Pub/Sub: Dataframe example

This demo shows the pub/sub message style using as message topic `dataframe` and
as message value a dataframe object.

Files:

- `df_pub.jl`
- `df_sub.jl`

Start two subscribers using two REPLs:

```bash
j -i df_sub.jl sub1
j -i df_sub.jl sub2
```

Start the publisher and send a dataframe with 5 rows:

```bash
j -i df_pub.jl 5
```

The file `df_pub.jl` defines a the function `rows(n)` that
returns a DataFrame with `n` rows and 4 columns.

Using the publisher REPL it is possible to send another dataframe with:

```julia
@publish dataframe(rows(2), "v1.1")
```

The `dataframe` topic expects a DataFrame and optionally a String.

The `df_sub.jl` subscribes to topic `dataframe` and shares with the
`dataframe` method a context object:

```julia
mutable struct Ctx
    name::Union{Nothing,String}
    df::Union{Nothing,DataFrame}
    Ctx() = new(nothing, nothing)
end

function dataframe(ctx, df, name=nothing)
    ctx.df = df
    ctx.name = name
    @info ctx
end

ctx = Ctx()
@subscribe dataframe before_now
@shared ctx
```

The `ctx` object contains the last received dataframe:

```cli
julia> ctx
Ctx("v1.1", 2×4 DataFrame
 Row │ str_col  int_col  float_col  missing_col
     │ String   Int64    Float64    Int64?
─────┼──────────────────────────────────────────
   1 │ name_1         1        1.0      missing
   2 │ name_2         2        2.0            2)
```

There are two ways to subscribe to a topic:

To declare interest for messages published from now on: 

```julia
# Receive by default messages published from now on
@subscribe topic

# Declare explicity the type of interest
@subscribe topic from_now
```

To receive messages published before the subscription instant:

```julia
@subscribe topic before_now
```

## Conditional Pub/Sub

This sample is kept very simple for demo purpose, but
a motivating use case it is the scenario when a RPC command executes
CRUD operations on a database, and after a transaction complete successfully,
a set of components are immediately notified of the status change.

Files:

- `conditional_expose.jl`
- `conditional_subscribe.jl`

The topic `registration` conveys messages of people that want to be admitted
to a list of universities:

```julia
@rpc registration("Mario Rossi", 29, ["Milano", "Trento"])
```

Registration is conditioned by satisfying certain rules, which for simplicity we assume here
as the score above a certain value.

`conditional_expose.jl`:

```julia
function registration(name::String, score::Number, preferences::Vector{String})
    if score > 30
        return "ok"
    else
        error("score $score is too low")
    end
end
```

a client invokes the rpc topic `registration` with the requested infos and if and only if
the registration pass the checks the original infos are broadcasted to all
subscribed components that get notified of the successful registration.

```shell
# start the broker
terminal1> julia -i caronte.jl

# milano and trento subscribe
terminal2> julia conditional_subscribe.jl milano
terminal3> julia conditional_subscribe.jl trento

# registration server that check if registration is valid
terminal4> julia conditional_expose.jl
```

A client component is now able to send a registration request:

```julia
using Rembus

# registration accepted, subscribers get notified
@rpc registration("Mario", 31, ["Trento", "Milano"])

# registration is not accepted, an error exception implies that 
# subscribers are not notified
@rpc registration("Francesco", 15, ["Padova", "Milano"])
```

## RPC and Pub/Sub mixing

This sample employs both Pub/Sub and Rpc styles to implements the following functionalities.

- Read a pollution data file placed into a folder and make available the file content to
all interested parties.
- Store the data into a DuckDB database.
- Backup the file into a destination directory.
- Query the data at rest in the database.
- Send an alarm message for each read record when specific pollutant exceeds a threshold value.

Files:

- `watcher_caronte.jl`: starts a broker and watches a target directory for csv data files and publishes
the files content to `pollution` topic.
- `watcher_db.jl`: subscribes to `pollution` topic and upoloads the data to a DuckDB in-memory database.
Exposes the `query` method to select data from database.
- `watcher_copy.jl`: subscribes to `pollution` and makes a backup of received files into a destination directory.
- `watcher_alarm.jl`: subscribes to `pollution` and publishes alarms to `alarm` topic when a pollutant value
exceed a threshold.

Start the broker and the file watcher:

```shell
cli1> j -i watcher_caronte.jl -r
```

Note that the after the source file is loaded an interactive REPL is available
because `caronte()` is invoked with `wait=false`.

The `-r` flag reset all the twins states from the broker.

Inspect the running processes:

```julia
Visor.dump()
[root] nodes: ["supervisor:caronte(running)", "watch_task(running)"]
[caronte] nodes: ["supervisor:twins(running)", "broker(running)", "serve_ws(running)"]
[twins] nodes: String[]
```

Alongside the caronte processes there is the `watch_task` responsible for watching for new files
inside a folder.

Start the duckdb component and the alarm monitor component into two
separate terminals:

```shell
cli2> j watcher_db.jl 
cli3> j watcher_alarm.jl 
```

and start `watcher_copy.jl` if you want also the backup functionality:

```shell
cli4> mkdir dst
cli4> j watcher_copy.jl 
```

Finally if you want to be notified for alarms start another simple component:

```julia
using Rembus

alarm(msg) = @info "ALARM>> $msg"

@subscribe alarm
@forever
```

### Fault-tolerance: Visor.jl

For showing the fault-tolerant capabilities of `Visor.jl` the following lines are inserted into
the method `watch_task`:

```julia
if fn === "foo"
    error("harakiri")
end
```

When a file named `foo` is moved into the watched folder then an unpredictable exception is thrown.

The task terminates by the undesiderable `harachiri` occurence but the root supervisor will
restart the task. 

> Note that actually `watch_task` caputures the exception and returns normally. The supervisor restarts
> the task because it is declared `permanent`. If the restart strategy is not declared the supervisor
> will restart tasks that exit after throwing an exception.

```julia
process(watch_task, args=(args["watchdir"],), restart=:permanent)
```


You can see this in action:

```shell
# with linux
cli5> touch foo

# with windows powershell
cli5> ni foo

cli5> cp foo src
```

And in the REPL of `watcher_caronte.jl`:

```julia
harakiri
Stacktrace:
 [1] watch_task(pd::Visor.Process, wdir::String)
   @ Main C:\Users\so000112\dev\juliacon2024\watcher_caronte.jl:51
 [2] (::Visor.var"#19#22"{Visor.Process})()
   @ Visor C:\Users\so000112\.julia\packages\Visor\tJMOR\src\Visor.jl:461[2024-06-23T11:19:37.913][Main][1][Info] watch_task done
[2024-06-23T11:19:37.914][Main][1][Info] watch_task start, watchdir: [src]
```

`watch_task` exited by the "unpredictable" `harachiri` exception but the good news is reported by the `[Info]`
trace that states that the task was restarted successfully by the supervisor provided by `Visor.jl`.

As a couterproof inspect processes state again with `Visor.dump()`:

```julia
cli1:julia> Visor.dump()
[root] nodes: ["supervisor:caronte(running)", "watch_task(running)"]
[caronte] nodes: ["supervisor:twins(running)", "broker(running)", "serve_ws(running)"]
[twins] nodes: String[]
```