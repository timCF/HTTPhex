defmodule HttphexTest do
  use ExUnit.Case
  use Httphex, 	[
  					def_host: "https://api.vk.com", 
  					def_opts: [],
  					folsom: true,
  					verbose: true
  				]
  #
  # redefine routes postfix (it's override)
  #
  defp routes_postfix(routes) do
  	case routes do
  		["method","groups.get"] -> "vk_test"
  		_ -> "other"
  	end
  end


  test "get err from vk.com" do
  	assert (http_get(%{}, ["method","groups.get"]) |> IO.inspect |> is_map) == true
  end
end
