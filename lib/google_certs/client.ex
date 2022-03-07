defmodule GoogleCerts.Client do
  @moduledoc """
  HTTP Client
  """

  require Logger
  alias GoogleCerts.Env

  defmodule Response do
    @moduledoc """
    Google Cert Client Response
    """
    @type t :: %__MODULE__{expiration: DateTime.t(), cert: map()}

    defstruct expiration: DateTime.utc_now(), cert: %{}

    @spec new(DateTime.t(), map()) :: Response.t()
    def new(exp, cert), do: %__MODULE__{expiration: exp, cert: cert}
  end

  defp host, do: Env.google_host()

  defp uri_path(1), do: {:ok, "/oauth2/v1/certs"}
  defp uri_path(2), do: {:ok, "/oauth2/v2/certs"}
  defp uri_path(3), do: {:ok, "/oauth2/v3/certs"}
  defp uri_path(_), do: {:error, :no_cert_version_path}

  defp req_headers, do: [{"content-type", "application/json"}]

  @callback get(binary(), list()) :: {:ok, :hackney.client_ref()} | {:error, term()}
  @callback body(any()) :: {:error, atom | {:closed, binary}} | {:ok, binary}

  defp http_client, do: Application.get_env(Env.app(), :http_client, :hackney)

  @spec get(integer()) :: {:ok, Response.t()} | {:error, :req_google_certs}
  def get(version) do
    with {:ok, path} <- uri_path(version),
         {:req, {:ok, 200, headers, response}} <-
           {:req, http_client().get(host() <> path, req_headers())},
         {:ok, seconds} <- max_age(headers),
         {:expiration, {:ok, expiration}} <- {:expiration, expiration(seconds)},
         {:content, {:ok, body}} <- {:content, http_client().body(response)},
         {:ok, decoded} <- Jason.decode(body) do
      {:ok, Response.new(expiration, decoded)}
    else
      error ->
        Logger.error(
          "Error getting google certs (version #{inspect(version)}). Error: #{inspect(error)}"
        )

        {:error, :req_google_certs}
    end
  end

  defp max_age(headers) do
    with {:ok, cache_control} <- fetch_cache_control(headers),
         {:ok, max_age} <- parse_max_age(cache_control),
         {value, _} <- Integer.parse(max_age) do
      {:ok, value}
    else
      error ->
        Logger.error("error getting max age from response headers. Error: " <> inspect(error))
        {:error, :no_max_age}
    end
  end

  defp parse_max_age(value) do
    case Regex.named_captures(~r/.*max-age=(?<max_age>\d+)/, value) do
      %{"max_age" => seconds} -> {:ok, seconds}
      _ -> {:error, :no_max_age}
    end
  end

  defp fetch_cache_control(headers) do
    case headers |> normalize_headers() |> List.keyfind("cache-control", 0, :not_found) do
      {"cache-control", value} -> {:ok, value}
      _ -> {:error, :no_cache_control}
    end
  end

  defp normalize_headers([]), do: []

  defp normalize_headers(headers) when is_list(headers) do
    Enum.map(headers, fn header ->
      {key, rest} = header |> Tuple.to_list() |> List.pop_at(0)

      if is_nil(key) do
        []
      else
        [String.downcase(key) | rest]
        |> List.to_tuple()
      end
    end)
  end

  defp expiration(scnds), do: {:ok, DateTime.add(DateTime.utc_now(), scnds, :second)}
end
