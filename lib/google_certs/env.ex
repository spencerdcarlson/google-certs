defmodule GoogleCerts.Env do
  @moduledoc """
  Centralized way to access environment variables
  """

  require Logger
  @app :google_certs
  @defaults [
    library_version: "unset",
    filename: "google.oauth2.certificates.json",
    google_certs_host: "https://www.googleapis.com",
    api_version: 3,
    auto_start?: true,
    write_to_disk?: false,
    load_from_disk?: false
  ]

  @doc """
  OTP Application name
  """
  @spec app :: atom()
  def app, do: @app

  @doc """
  Current library version
  """
  @spec library_version :: binary
  def library_version do
    app()
    |> Application.spec()
    |> Keyword.get(:vsn, @defaults[:library_version])
    |> to_string()
  end

  @doc """
  Directory to write certs if `GoogleCerts.Env.write_to_disk?/0` is enabled

  * default: Application `priv` directory
  * System Env: `GOOGLE_CERTS_CACHE_FILEPATH`
  * Elixir Config: `:cache_filepath`
  """
  @spec cache_path :: String.t()
  def cache_path do
    value = get_env("GOOGLE_CERTS_CACHE_FILEPATH", :cache_filepath, default_cache_path())

    with path when is_binary(path) <- parse_value(value),
         true <- File.dir?(path) do
      path
    else
      _ ->
        Logger.warn("Error parsing the user's cache filepath. Falling back to default")
        default_cache_path()
    end
  end

  defp default_cache_path do
    case :application.get_application() do
      {:ok, app} ->
        :code.priv_dir(app)

      _ ->
        tmp_dir = System.tmp_dir!()

        Logger.warn(
          "Error getting the /priv directory of the host app. Falling back to #{inspect(tmp_dir)} dir"
        )

        tmp_dir
    end
  end

  @doc """
  Filename to write certs if `GoogleCerts.Env.write_to_disk?/0` is enabled

  * default: `"google.oauth2.certificates.json"`
  * System Env: `GOOGLE_CERTS_FILENAME`
  * Elixir Config: `:filename`
  """
  @spec file_name :: String.t()
  def file_name do
    default = @defaults[:filename]
    value = get_env("GOOGLE_CERTS_FILENAME", :filename, default)

    case parse_value(value) do
      filename when is_binary(filename) ->
        filename

      _ ->
        Logger.error("Error parsing the user's filename. Falling back to default")
        default
    end
  end

  @doc """
  Auto start the `GoogleCerts.CertificateCache` Agent.

  * default: `true`
  * System Env: `GOOGLE_CERTS_ENABLE_AUTO_START`
  * Elixir Config: `:auto_start?`
  """
  @spec auto_start? :: boolean()
  def auto_start? do
    default = @defaults[:auto_start?]
    value = get_env("GOOGLE_CERTS_ENABLE_AUTO_START", :auto_start?, default)

    case parse_value(value) |> String.to_atom() do
      value when is_boolean(value) ->
        value

      _ ->
        Logger.error("Error parsing enable auto start option. Falling back to default")
        default
    end
  end

  @doc """
  Library will write certs to disk

  * default: `false`
  * System Env: `GOOGLE_CERTS_ENABLE_WRITE_TO_DISK`
  * Elixir Config: `:write_to_disk?`
  """
  @spec write_to_disk? :: boolean()
  def write_to_disk? do
    default = @defaults[:write_to_disk?]
    value = get_env("GOOGLE_CERTS_ENABLE_WRITE_TO_DISK", :write_to_disk?, default)

    case parse_value(value) |> String.to_atom() do
      value when is_boolean(value) ->
        value

      _ ->
        Logger.error("Error parsing write to disk option. Falling back to default")
        default
    end
  end

  @doc """
  Library will attempt to load certs from disk

  * default: `false`
  * System Env: `GOOGLE_CERTS_ENABLE_LOAD_FROM_DISK`
  * Elixir Config: `:load_from_disk?`
  """
  @spec load_from_disk? :: boolean()
  def load_from_disk? do
    default = @defaults[:load_from_disk?]
    value = get_env("GOOGLE_CERTS_ENABLE_LOAD_FROM_DISK", :load_from_disk?, default)

    case parse_value(value) |> String.to_atom() do
      value when is_boolean(value) ->
        value

      _ ->
        Logger.error("Error parsing load from disk option. Falling back to default")
        default
    end
  end

  @doc """
  Google URI host

  * default: `"https://www.googleapis.com"`
  * System Env: `GOOGLE_CERTS_HOST`
  * Elixir Config: `:google_certs_host`
  """
  @spec google_host :: String.t()
  def google_host do
    default = @defaults[:google_certs_host]
    value = get_env("GOOGLE_CERTS_HOST", :google_certs_host, default)

    case parse_value(value) do
      host when is_binary(host) ->
        host

      _ ->
        Logger.error("Error parsing the user's google certs host. Falling back to default")
        default
    end
  end

  @doc """
  Google API version

  * default: `3`
  * System Env: `GOOGLE_CERTS_API_VERSION`
  * Elixir Config: `:api_version`
  """
  @spec api_version :: integer()
  def api_version do
    default = @defaults[:api_version]
    value = get_env("GOOGLE_CERTS_API_VERSION", :api_version, default)

    case value |> parse_value() |> to_number(default) do
      version when is_number(version) and version in 1..3 ->
        version

      _ ->
        Logger.error("Error parsing the user's google api version. Falling back to default")
        default
    end
  end

  defp get_env(string_key, atom_key, default) do
    default =
      case Application.get_env(app(), atom_key, default) do
        value when is_binary(value) -> value
        value -> inspect(value)
      end

    System.get_env(string_key, default)
  end

  defp parse_value(list) when is_list(list) do
    Enum.map(list, &parse_value/1)
  end

  defp parse_value(atom) when is_atom(atom), do: atom

  defp parse_value(string) when is_binary(string) do
    if string =~ ";" do
      string
      |> String.split(";")
      |> Enum.map(&String.trim/1)
    else
      string
    end
  end

  defp parse_value(number) when is_number(number), do: number
  defp parse_value(nil), do: nil
  defp parse_value(_), do: nil

  defp to_number(value, _) when is_number(value), do: value

  defp to_number(value, default) when is_binary(value) do
    String.to_integer(value)
  rescue
    _ -> default
  end

  defp to_number(_, default), do: default
end
