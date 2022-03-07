defmodule GoogleCerts.Case do
  @moduledoc false

  use ExUnit.CaseTemplate
  @app :google_certs

  using do
    quote do
      alias GoogleCerts
      alias GoogleCerts.{Certificate, Certificates}
      import Mox
    end
  end

  setup _context do
    # clear defaults and set them
    [
      {:api_version, "GOOGLE_CERTS_API_VERSION", 3},
      {:auto_start?, "GOOGLE_CERTS_ENABLE_AUTO_START", true},
      {:cache_filepath, "GOOGLE_CERTS_CACHE_FILEPATH", "google.oauth2.certificates.json"},
      {:filename, "GOOGLE_CERTS_FILENAME", "google.oauth2.certificates.json"},
      {:google_certs_host, "GOOGLE_CERTS_HOST", "https://www.googleapis.com"},
      {:load_from_disk?, "GOOGLE_CERTS_ENABLE_LOAD_FROM_DISK", false},
      {:write_to_disk?, "GOOGLE_CERTS_ENABLE_WRITE_TO_DISK", false}
    ]
    |> Enum.each(fn {key, env, value} ->
      Application.delete_env(@app, key)
      System.delete_env(env)
      Application.put_env(@app, key, value)
    end)

    :ok
  end
end
