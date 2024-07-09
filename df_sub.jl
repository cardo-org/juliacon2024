using DataFrames
using Rembus

if isempty(ARGS)
    component = "df_subscriber"
else
    component = ARGS[1]
end

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
@component component

@subscribe dataframe before_now
@shared ctx

@info "[$component] subscribed to topic [dataframe]"
@forever
