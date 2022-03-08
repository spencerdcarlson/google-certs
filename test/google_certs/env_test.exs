defmodule GoogleCerts.EnvTest do
  use GoogleCerts.Case
  use ExUnit.Case, async: false
  alias GoogleCerts.Env

  describe "Env" do
    test "has a default value for each value" do
      assert Env.file_name() == "google.oauth2.certificates.json"
      assert Env.google_host() == "https://www.googleapis.com"
      assert Env.cache_path() |> File.dir?()
      assert Env.api_version() == 3
      assert Env.auto_start?()
      refute Env.load_from_disk?()
      refute Env.write_to_disk?()
    end

    test "can be set as an elixir config" do
      temp_dir = System.tmp_dir!()

      envs = [
        filename: "config-test.json",
        google_certs_host: "https://httpstat.us/400",
        cache_filepath: temp_dir,
        api_version: 2
      ]

      Enum.each(envs, fn {env, value} -> Application.put_env(:google_certs, env, value) end)

      assert Env.file_name() == "config-test.json"
      assert Env.google_host() == "https://httpstat.us/400"
      assert Env.cache_path() == temp_dir
      assert Env.api_version() == 2
    end

    test "can be set using System environment variables" do
      temp_dir = System.tmp_dir!()

      envs = [
        {"GOOGLE_CERTS_FILENAME", "env-test.json"},
        {"GOOGLE_CERTS_HOST", "https://httpstat.us/200"},
        {"GOOGLE_CERTS_CACHE_FILEPATH", temp_dir},
        {"GOOGLE_CERTS_API_VERSION", "1"}
      ]

      Enum.each(envs, fn {env, value} -> System.put_env(env, value) end)

      assert Env.file_name() == "env-test.json"
      assert Env.google_host() == "https://httpstat.us/200"
      assert Env.cache_path() == temp_dir
      assert Env.api_version() == 1
    end
  end
end
