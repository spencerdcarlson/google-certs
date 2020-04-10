defmodule GoogleCerts.CertificateCache do
  @moduledoc """
  Agent to hold the current public certs that google uses to sign JWTs
  """

  use Agent
  require Logger
  alias GoogleCerts.{CertificateDecodeException, Certificates}

  @default_certificate_version 3
  defp certificate_version do
    Application.get_env(:google_certs, :version, @default_certificate_version)
  end

  def start_link([]) do
    case load() do
      {:ok, certs = %Certificates{}} ->
        Logger.debug("Cache certificates from disk")
        start_link(certs)

      _ ->
        Logger.debug("Cache empty certificates")

        %Certificates{}
        |> Certificates.set_version(certificate_version())
        |> start_link()
    end
  end

  def start_link(certs = %Certificates{}) do
    Agent.start_link(
      fn ->
        certs |> GoogleCerts.refresh() |> serialize()
      end,
      name: __MODULE__
    )
  end

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

  defp serialize(certs = %Certificates{}) do
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
  end

  defp path do
    case :application.get_application() do
      {:ok, app} ->
        app
        |> :code.priv_dir()
        |> Path.join("google.oauth2.certificates.json")

      _ ->
        "/tmp/google.oauth2.certificates.json"
    end
  end
end
