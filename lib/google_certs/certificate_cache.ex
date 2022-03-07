defmodule GoogleCerts.CertificateCache do
  @moduledoc """
  Agent to hold the current public certs that google uses to sign JWTs
  """

  use Agent
  require Logger
  alias GoogleCerts.{CertificateDecodeException, Certificates, Env}

  @spec certificate_version :: integer()
  defp certificate_version, do: Env.api_version()

  @spec start_link([] | Certificates.t()) :: GenServer.on_start()
  def start_link([]) do
    if Env.load_from_disk?() do
      case load() do
        {:ok, certs = %Certificates{}} ->
          Logger.debug("Cache certificates from disk")
          start_link(certs)

        _ ->
          Logger.debug("Cache empty certificates")

          cold_start()
      end
    else
      cold_start()
    end
  end

  def start_link(certs = %Certificates{}) do
    if Env.auto_start?() do
      Agent.start_link(
        fn -> GoogleCerts.refresh(certs) end,
        name: __MODULE__
      )
    else
      :ignore
    end
  end

  defp cold_start do
    %Certificates{}
    |> Certificates.set_version(certificate_version())
    |> start_link()
  end

  @doc """
  Get and refresh GoogleCerts.

  Cached GoogleCerts are returned if they are not expired, otherwise a network request is made
  to get and cache the latest certificates. See `GoogleCerts.refresh/1`
  """
  @spec get :: GoogleCerts.Certificates.t()
  def get, do: Agent.get(__MODULE__, & &1) |> GoogleCerts.refresh()

  defp load do
    with {:file_path, file_path} <- {:file_path, path()},
         {:file_exists?, true} <- {:file_exists?, File.exists?(file_path)},
         {:read_file, {:ok, json}} <- {:read_file, File.read(file_path)} do
      try do
        certs = Certificates.decode!(json)
        Logger.debug("Certificates were loaded from disk.")
        {:ok, certs}
      rescue
        e in [CertificateDecodeException, Jason.DecodeError] ->
          Logger.warn(
            "There was an error loading certificates from disk. #{Map.get(e, :message, "")}"
          )

          {:error, :decode_certs}
      end
    else
      error ->
        Logger.warn("Could not load certs from file. details: " <> inspect(error))
        {:error, :load_certificates}
    end
  end

  @spec serialize(Certificates.t()) :: Certificates.t()
  def serialize(certs = %Certificates{}) do
    if Env.write_to_disk?() do
      with {:file_path, file_path} <- {:file_path, path()},
           {:open_file, {:ok, file}} <- {:open_file, File.open(file_path, [:write])},
           {:encode, {:ok, json}} <- {:encode, Jason.encode(certs)},
           {:write, :ok} <- {:write, IO.binwrite(file, json)},
           {:close, :ok} <- {:close, File.close(file)} do
        Logger.debug("Saved certificates. location: #{inspect(file_path)}")
        certs
      else
        error ->
          Logger.error("Error serializing certificates. Error: " <> inspect(error))
          certs
      end
    else
      Logger.debug("Writing certs to disk is disabled.")
      certs
    end
  end

  defp path, do: Path.join(Env.cache_path(), Env.file_name())
end
