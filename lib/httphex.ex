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

  defmacro __using__(macroopts) do

    encode = case macroopts[:encode] in [:json, :none] do
                true -> macroopts[:encode]
                false -> 
                  #case is_function(macroopts[:encode], 1) do
                  case is_tuple(macroopts[:encode]) or is_function(macroopts[:encode], 1) do
                    true -> macroopts[:encode]
                    false -> raise "#{__MODULE__} : plz define encoding using by default :json | :none | func"
                  end
              end

    decode = case macroopts[:decode] in [:json, :none] do
                true -> macroopts[:decode]
                false -> 
                  #case is_function(macroopts[:decode], 1) do
                  #
                  # TODO : how check func in AST???
                  #
                  case is_tuple(macroopts[:decode]) or is_function(macroopts[:decode], 1) do
                    true -> macroopts[:decode]
                    false -> raise "#{__MODULE__} : plz define decoding using by default :json | :none | func"
                  end
              end

    gunzip = case is_boolean(macroopts[:gzip]) do
                true -> macroopts[:gzip]
                false -> raise "#{__MODULE__} : plz define gzip flag"
              end

    def_headers_post = case {macroopts[:gzip], macroopts[:encode]} do
                        {true, :json} -> quote do %{"Accept-Encoding" => "deflate, gzip", "Content-type" => "application/json"} end
                        {true, _} -> quote do %{"Accept-Encoding" => "deflate, gzip"} end
                        {false, :json} -> quote do %{"Content-type" => "application/json"} end
                        {false, _} -> quote do  %{} end
                      end
    def_headers_get = case macroopts[:gzip] do
                        false -> quote do %{} end
                        true -> quote do %{"Accept-Encoding" => "deflate, gzip"} end
                      end

    def_host =  case macroopts[:host] do
                  bin when is_binary(bin) -> bin
                  _ -> raise "#{__MODULE__} : plz, define host in opts."
                end
    def_opts =  case macroopts[:opts] do
                  lst when is_list(lst) -> lst
                  _ -> raise "#{__MODULE__} : plz define settings using by default, example : [hackney: [basic_auth: {usr, psswd}]]"
                end

    def_settings_get = quote do %{host: unquote(def_host), opts: unquote(def_opts), headers: unquote(def_headers_get), gzip: unquote(gunzip), decode: unquote(decode)} end
    def_settings_post = quote do %{host: unquote(def_host), opts: unquote(def_opts), headers: unquote(def_headers_post), encode: unquote(encode), gzip: unquote(gunzip), decode: unquote(decode)} end

    quote location: :keep do
      require Exutils
      require Logger

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

      defp not_null(setts, defs, key) do
        case Map.get(setts, key) do
          nil ->  case Map.get(defs, key) do
                    nil -> raise "#{__MODULE__} : can't get #{inspect key} for http q"
                    some -> some 
                  end
          some -> some
        end
      end


      defp __uncomp_proc__(body, true), do: :zlib.gunzip(body)
      defp __uncomp_proc__(body, false), do: body
      defp __decode_proc__(body, :json), do: :jiffy.decode(body, [:atom_keys, :return_maps, :use_nil])
      defp __decode_proc__(body, :none), do: body
      defp __decode_proc__(body, func), do: func.(body)
      defp __after_q__(body, gzip, decode, routes) do 
        {time, res} = :timer.tc(fn() -> __uncomp_proc__(body, gzip) |> __apply_body_callback__(routes) |> __decode_proc__(decode) |> Exutils.safe end)
        time_decode_callback(routes, div(time, 1000))
        res
      end
      defp __apply_body_callback__(body, routes) do
        body_callback(routes, body)
        body
      end


      # GET

      defp http_get(args \\ %{}, routes \\ [], settings \\ unquote(def_settings_get))
      defp http_get(args, routes, settings) when is_binary(routes) do
        http_get(args, [routes], settings)
      end
      defp http_get(args, routes, settings) do

        host = not_null(settings, unquote(def_settings_get), :host)
        opts = not_null(settings, unquote(def_settings_get), :opts)
        headers = not_null(settings, unquote(def_settings_get), :headers)
        gzip = not_null(settings, unquote(def_settings_get), :gzip)
        decode = not_null(settings, unquote(def_settings_get), :decode)

        {time, ans_data} = :timer.tc(fn() -> __binq__( args, routes, host ) |> HTTPoison.get(headers, opts) |> Exutils.safe end)
        time_http_callback(routes, div(time, 1000))
        case ans_data do
          %HTTPoison.Response{status_code: 200, body: body} ->        __after_q__(body, gzip, decode, routes) 
          {:ok, %HTTPoison.Response{status_code: 200, body: body}} -> __after_q__(body, gzip, decode, routes)
          error -> {:error, error}
        end
      end

      # POST

      defp __encode_content__(content, :json), do: :jiffy.encode(content)
      defp __encode_content__(content, :none), do: content
      defp __encode_content__(content, func), do: func.(content)


      defp http_post(content, routes \\ [], settings \\ unquote(def_settings_post))
      defp http_post(content, routes, settings) when is_binary(routes) do
        http_post(content, [routes], settings)
      end
      defp http_post(content, routes, settings) do

        host = not_null(settings, unquote(def_settings_post), :host)
        opts = not_null(settings, unquote(def_settings_post), :opts)
        headers = not_null(settings, unquote(def_settings_post), :headers)
        encode = not_null(settings, unquote(def_settings_post), :encode)
        gzip = not_null(settings, unquote(def_settings_post), :gzip)
        decode = not_null(settings, unquote(def_settings_post), :decode)

        {time, ans_data} = :timer.tc(fn() -> __binq__( %{}, routes, host ) |> HTTPoison.post(__encode_content__(content, encode), headers, opts) |> Exutils.safe end)
        time_http_callback(routes, div(time, 1000))
        case ans_data do
          %HTTPoison.Response{status_code: 200, body: body} ->        __after_q__(body, gzip, decode, routes) 
          {:ok, %HTTPoison.Response{status_code: 200, body: body}} -> __after_q__(body, gzip, decode, routes) 
          error -> {:error, error}
        end
      end

      #
      # by default, callbacks do nothing, it's overridable
      #

      defp time_http_callback(_routes, _time), do: nil
      defp time_decode_callback(_routes, _time), do: nil
      defp body_callback(_routes, _body), do: nil

      defoverridable [time_http_callback: 2, time_decode_callback: 2, body_callback: 2]

    end
  end
end