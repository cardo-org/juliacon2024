using Rembus

cid = ARGS[1]
@component cid

function registration(name, score, preferences)
    @info "[$cid] new registration: $name with score $score with preferences $preferences"
end

@subscribe registration before_now

@info "$cid ready"
@forever
