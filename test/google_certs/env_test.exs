defmodule GoogleCerts.EnvTest do
  use ExUnit.Case, async: false
  alias GoogleCerts.Env

  setup :remove_configs
  @app :google_certs

  describe "Env" do
    test "has a default value for each value" do
      assert Env.file_name() == "google.oauth2.certificates.json"
      assert Env.google_host() == "https://www.googleapis.com"
      assert Env.cache_path() == "/tmp"
      assert Env.api_version() == 3
    end

    test "can be set as an elixir config" do
      envs = [
        filename: "config-test.json",
        google_certs_host: "https://httpstat.us/400",
        cache_filepath: "/dev",
        api_version: 2
      ]

      Enum.each(envs, fn {env, value} -> Application.put_env(@app, env, value) end)

      assert Env.file_name() == "config-test.json"
      assert Env.google_host() == "https://httpstat.us/400"
      assert Env.cache_path() == "/dev"
      assert Env.api_version() == 2
    end

    test "can be set using System environment variables" do
      envs = [
        {"GOOGLE_CERTS_FILENAME", "env-test.json"},
        {"GOOGLE_CERTS_HOST", "https://httpstat.us/200"},
        {"GOOGLE_CERTS_CACHE_FILEPATH", "/var"},
        {"GOOGLE_CERTS_API_VERSION", "4"}
      ]

      Enum.each(envs, fn {env, value} -> System.put_env(env, value) end)

      assert Env.file_name() == "env-test.json"
      assert Env.google_host() == "https://httpstat.us/200"
      assert Env.cache_path() == "/var"
      assert Env.api_version() == 4
    end
  end

  def remove_configs(_context) do
    envs = [
      {:filename, "GOOGLE_CERTS_FILENAME"},
      {:google_certs_host, "GOOGLE_CERTS_HOST"},
      {:cache_filepath, "GOOGLE_CERTS_CACHE_FILEPATH"},
      {:api_version, "GOOGLE_CERTS_API_VERSION"}
    ]

    Enum.each(envs, fn {config, env} ->
      Application.delete_env(@app, config)
      System.delete_env(env)
    end)

    on_exit(&restore_configs/0)
  end

  def restore_configs do
    envs = [
      filename: "google.oauth2.certificates.json",
      google_certs_host: "https://www.googleapis.com",
      api_version: 3
    ]

    Enum.each(envs, fn {env, value} -> Application.put_env(@app, env, value) end)
  end
end
