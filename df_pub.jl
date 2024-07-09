using DataFrames
using Rembus

n = 5
if !isempty(ARGS)
    n = parse(Int, ARGS[1])
end

function rows(n)
    rows = 1:n
    return DataFrame(
        :str_col => ["name_$i" for i in rows],
        :int_col => rows,
        :float_col => Float64.(rows),
        :missing_col => [isodd(i) ? missing : i for i in rows]
    )
end

@component "publisher"
@publish dataframe(rows(n))
