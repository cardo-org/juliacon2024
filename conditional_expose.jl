using Rembus

function registration(name::String, score::Number, preferences::Vector{String})
    if score > 30
        return "ok"
    else
        error("score $score is too low")
    end
end

@expose registration

@info "registration server ready"
@forever
