defmodule HttphexTest do
  use ExUnit.Case
  use Httphex, 	[
        					host: "https://api.vk.com", 
        					opts: [],
        					encode: :none, # here can be lambda
        					decode: :json, # here can be lambda
                  			gzip: false,
                  			client: :httpotion
        				]

  test "get err from vk.com" do
  	assert (http_get(%{}, ["method","groups.get"]) |> IO.inspect |> is_map) == true
  end

  test "get users profiles from vk.com" do
    assert (http_get(%{user_ids: "1785932,43214"}, ["method","users.get"]) |> IO.inspect |> is_map) == true
  end

  defp time_http_callback(routes, time) do
    Logger.debug "#{__MODULE__} : query to #{inspect routes} take #{time} ms"
  end
  defp time_decode_callback(routes, time) do
    Logger.debug "#{__MODULE__} : decoding of query to #{inspect routes} take #{time} ms"
  end
  defp body_callback(routes, body) do
    Logger.debug "#{__MODULE__} : size of answer from #{inspect routes} is #{String.length(body)} bytes"
  end

end
