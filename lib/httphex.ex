defmodule Httphex do
  use Application

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      # Define workers and child supervisors to be supervised
      # worker(Httphex.Worker, [arg1, arg2, arg3])
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Httphex.Supervisor]
    Supervisor.start_link(children, opts)
  end

  ##################################
  ##  operate with http queries  ###
  ##################################

  import HttphexHelper

  defmacro __using__(macroopts) do
    quote location: :keep do
      
      require Exutils
      require Logger
      use HttphexHelper, unquote(macroopts)

      defp __make_arg__({key, value}), do: "#{key}=#{URI.encode_www_form to_string(value)}"
      defp __make_args__(args), do: Map.to_list(args) |> Enum.map(&__make_arg__/1) |> Enum.join("&")

      defp __binq__( args, routes, host ) do
        ([host|routes]|> Enum.join("/"))
        <>
        (case __make_args__(args) do
          "" -> ""
          res -> "?"<>res
        end)
      end

      # GET

      defp http_get(args \\ %{}, routes \\ [], opts \\ unquote(def_opts(macroopts)), host \\ unquote(def_host(macroopts)))
      defp http_get(args, routes, opts, host) when is_binary(routes) do
        http_get(args, [routes], opts, host)
      end
      defp http_get(args, routes, opts, host) do
        begin = unquote(folsom_timer(macroopts))
        case __binq__( args, routes, host ) 
            |> HTTPoison.get(%{"Accept-Encoding" => "deflate, gzip"}, opts)
              |> Exutils.safe do
          {:ok, %HTTPoison.Response{status_code: 200, body: json}} ->
            handle_folsom_http(routes, begin, json)
            begin = unquote(folsom_timer(macroopts))
            case json |> :zlib.gunzip |> :jiffy.decode([:atom_keys, :return_maps, :use_nil]) |> Exutils.safe do
              {:error, error} -> {:error, error}
              res ->  handle_folsom_json(routes, begin)
                      res
            end
          error -> {:error, error}
        end
      end

      # POST

      defp http_post(content, routes \\ [], opts \\ unquote(def_opts(macroopts)), host \\ unquote(def_host(macroopts)))
      defp http_post(content, routes, opts, host) when is_binary(routes) do
        http_post(content, [routes], opts, host)
      end
      defp http_post(content, routes, opts, host) do
        begin = unquote(folsom_timer(macroopts))
        case __binq__( %{}, routes, host ) 
            |> HTTPoison.post(__encode_content__(content), %{"Accept-Encoding" => "deflate, gzip", "Content-type" => "application/json"}, opts)
              |> Exutils.safe do
          {:ok, %HTTPoison.Response{status_code: 200, body: json}} ->
            handle_folsom_http(routes, begin, json)
            begin = unquote(folsom_timer(macroopts))
            case json |> :zlib.gunzip |> :jiffy.decode([:atom_keys, :return_maps, :use_nil]) |> Exutils.safe do
              {:error, error} -> {:error, error}
              res ->  handle_folsom_json(routes, begin)
                      res
            end
          error -> {:error, error}
        end
      end
      defp __encode_content__(content) when (is_list(content) or is_map(content)), do: :jiffy.encode(content)
      defp __encode_content__(content) when is_binary(content), do: content
      

      defp routes_postfix(_), do: "other"

      defoverridable [routes_postfix: 1]

    end
  end
end