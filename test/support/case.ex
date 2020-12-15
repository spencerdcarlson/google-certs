defmodule GoogleCerts.Case do
  @moduledoc false

  use ExUnit.CaseTemplate
  @app :google_certs

  using do
    quote do
      alias GoogleCerts
      alias GoogleCerts.{Certificate, Certificates}
      import Mock
    end
  end

  setup _context do
    # clear defaults and set them
    [
      {:filename, "GOOGLE_CERTS_FILENAME", "google.oauth2.certificates.json"},
      {:google_certs_host, "GOOGLE_CERTS_HOST", "https://www.googleapis.com"},
      {:cache_filepath, "GOOGLE_CERTS_CACHE_FILEPATH", "google.oauth2.certificates.json"},
      {:api_version, "GOOGLE_CERTS_API_VERSION", 2}
    ]
    |> Enum.each(fn {config, env, value} ->
      Application.delete_env(@app, config)
      System.delete_env(env)
      Application.put_env(@app, env, value)
    end)

    :ok
  end
end
