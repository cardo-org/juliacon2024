using Rembus

module Plug
using Rembus

export author

author(ctx, component) = "Attilio Donà"

end #Plug

sv = caronte(wait=false, plugin=Plug)
#wait(sv)
