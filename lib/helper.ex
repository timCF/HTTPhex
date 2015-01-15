defmodule HttphexHelper do

  require Logger
  require Exutils

  def def_host(opts) do
    case opts[:def_host] do
      bin when is_binary(bin) -> bin
      _ -> raise "#{__MODULE__} : plz define host using by default"
    end
  end

  def def_opts(opts) do
    case opts[:def_opts] do
      lst when is_list(lst) -> lst
      _ -> raise "#{__MODULE__} : plz define settings using by default, example : [hackney: [basic_auth: {usr, psswd}]]"
    end 
  end

  def folsom_timer(opts) do
    case opts[:folsom] do
      true -> quote do Exutils.makestamp end
      _ -> quote do nil end
    end
  end

  defmacro __using__(opts) do
    
    func1 = case {opts[:folsom], opts[:verbose]} do
              {true, true} -> 
                quote location: :keep do
                  defp handle_folsom_http(routes, begin,json) do
                    time_res = (Exutils.makestamp - begin) / 1000
                    len_res = String.length( json )
                    postfix = routes_postfix(routes)
                    Logger.info "#{__MODULE__} : time_http_#{postfix}} : #{time_res}"
                    Logger.info "#{__MODULE__} : size_http_#{postfix} : #{len_res}"
                    case {  :folsom_metrics.notify("time_http_#{postfix}", time_res), 
                            :folsom_metrics.notify("size_http_#{postfix}", len_res)     } do
                      {:ok, :ok} -> :ok
                      {:ok, err} -> Logger.error "#{__MODULE__} : metrics size_http_#{postfix} was not defined! Error #{inspect err}"
                      {err, :ok} -> Logger.error "#{__MODULE__} : metrics time_http_#{postfix} was not defined! Error #{inspect err}"
                      err -> Logger.error "#{__MODULE__} : metrics time_http_#{postfix} , size_http_#{postfix} was not defined! Error #{inspect err}"
                    end
                  end
                end
              {true, _} ->
                quote location: :keep do
                  defp handle_folsom_http(routes, begin,json) do
                    time_res = (Exutils.makestamp - begin) / 1000
                    len_res = String.length( json )
                    postfix = routes_postfix(routes)
                    case {  :folsom_metrics.notify("time_http_#{postfix}", time_res), 
                            :folsom_metrics.notify("size_http_#{postfix}", len_res)     } do
                      {:ok, :ok} -> :ok
                      {:ok, err} -> Logger.error "#{__MODULE__} : metrics size_http_#{postfix} was not defined! Error #{inspect err}"
                      {err, :ok} -> Logger.error "#{__MODULE__} : metrics time_http_#{postfix} was not defined! Error #{inspect err}"
                      err -> Logger.error "#{__MODULE__} : metrics time_http_#{postfix} , size_http_#{postfix} was not defined! Error #{inspect err}"
                    end
                  end
                end
              _ -> 
                quote do 
                  defp handle_folsom_http(_,_,_) do
                    nil 
                  end 
                end
            end

    func2 = case {opts[:folsom], opts[:verbose]} do
              {true, true} ->  
                quote location: :keep do
                  defp handle_folsom_json(routes, begin) do
                    time_res = (Exutils.makestamp - begin) / 1000
                    postfix = routes_postfix(routes)
                    Logger.info "#{__MODULE__} : time_zlib_jiffy_#{postfix} : #{time_res}"
                    case :folsom_metrics.notify("time_zlib_jiffy_#{postfix}", time_res) do
                      :ok -> :ok
                      err -> Logger.error "#{__MODULE__} : metrics time_zlib_jiffy_#{postfix} was not defined! Error #{inspect err}"
                    end
                  end
                end
              {true, _} -> 
                quote location: :keep do
                  defp handle_folsom_json(routes, begin) do
                    time_res = (Exutils.makestamp - begin) / 1000
                    postfix = routes_postfix(routes)
                    case :folsom_metrics.notify("time_zlib_jiffy_#{postfix}", time_res) do
                      :ok -> :ok
                      err -> Logger.error "#{__MODULE__} : metrics time_zlib_jiffy_#{postfix} was not defined! Error #{inspect err}"
                    end
                  end
                end
              _ -> quote do 
                    defp handle_folsom_json(_,_) do
                      nil 
                    end 
                  end
            end

    quote location: :keep do
      unquote(func1)
      unquote(func2)
    end

  end

end
