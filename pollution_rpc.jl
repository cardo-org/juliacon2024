using HTTP
using JSON3

# windows powershell:
# curl.exe -X GET 'http://localhost:9000/query2json' -d '[\"ancona\",\"o3\",150]'

function value(response)
    content = JSON3.read(response.body, Any)
    reason = "invalid response $content"
    if haskey(content, "status")
        if content["status"] == 0
            try
                return JSON3.read(content["value"], Any)
            catch e
                # if not a valid JSON return the string
                return content["value"]
            end
        elseif haskey(content, "value") && content["value"] !== nothing
            reason = content["value"]
        else
            reason = "code: $(content["status"])"
        end
    end
    error("error: $reason")
end

function create(city)
    res = HTTP.get(
        "http://127.0.0.1:9000/create", [], JSON3.write([city])
    )
    return value(res)
end

function query(city, element, thr)
    res = HTTP.get(
        "http://127.0.0.1:9000/query2json", [], JSON3.write([city, element, thr])
    )
    return value(res)
end
