defmodule HttphexTest do
  use ExUnit.Case
  use Httphex, 	[
        					host: "https://api.vk.com", 
        					opts: [],
        					encode: :none, # here can be lambda
        					decode: :json, # here can be lambda
                  gzip: false
        				]


  test "get err from vk.com" do
  	assert (http_get(%{}, ["method","groups.get"]) |> IO.inspect |> is_map) == true
  end

  test "get users profiles from vk.com" do
    assert (http_get(%{user_ids: "1785932,43214"}, ["method","users.get"]) |> IO.inspect |> is_map) == true
  end

end
