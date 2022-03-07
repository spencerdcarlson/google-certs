defmodule GoogleCertsTest do
  use GoogleCerts.Case
  use ExUnit.Case, async: true

  setup :verify_on_exit!

  setup_all do
    seconds = 19_721

    [
      seconds: seconds,
      headers: [{"Cache-Control", "public, max-age=#{seconds}, must-revalidate, no-transform"}],
      v1: ~s({"key1": "certificate 1", "key2": "certificate 2"}),
      v2: ~s({"keys": [{"kid": "key1", "n": "certificate 1"}]}),
      v3: ~s({"keys": [{"kid": "key1", "n": "certificate 1"}]})
    ]
  end

  describe "GoogleCerts.refresh" do
    test "handles version 1 format", %{headers: headers, v1: certs} do
      GoogleCerts.MockHTTPClient
      |> expect(:get, fn _, _ -> {:ok, 200, headers, :fake_ref} end)
      |> expect(:body, fn _ -> {:ok, certs} end)

      result = GoogleCerts.refresh(%Certificates{version: 1})

      assert match?(
               %Certificate{cert: %{"pem" => "certificate 1"}, kid: "key1"},
               Certificates.find(result, "key1")
             )

      assert match?(
               %Certificate{cert: %{"pem" => "certificate 2"}, kid: "key2"},
               Certificates.find(result, "key2")
             )
    end
  end

  test "handles version 2 format", %{headers: headers, v2: certs} do
    GoogleCerts.MockHTTPClient
    |> expect(:get, fn _, _ -> {:ok, 200, headers, :fake_ref} end)
    |> expect(:body, fn _ -> {:ok, certs} end)

    result = GoogleCerts.refresh(%Certificates{version: 2})

    assert match?(
             %Certificate{cert: %{"kid" => "key1", "n" => "certificate 1"}, kid: "key1"},
             Certificates.find(result, "key1")
           )
  end

  test "handles version 3 format", %{headers: headers, seconds: seconds, v3: certs} do
    GoogleCerts.MockHTTPClient
    |> expect(:get, fn _, _ -> {:ok, 200, headers, :fake_ref} end)
    |> expect(:body, fn _ -> {:ok, certs} end)

    result = GoogleCerts.refresh(%Certificates{version: 3})
    assert match?(%Certificates{expire: _, version: 3}, result)

    # Testing the `expired?` logic. Ideally the (now + max_age - expire) == 0,
    # but because we are dealing with time we need to add a buffer.
    buffer = :timer.hours(1) / 1_000

    assert DateTime.utc_now()
           |> DateTime.add(seconds, :second)
           |> DateTime.diff(Map.get(result, :expire)) < buffer

    assert match?(
             %Certificate{cert: %{"kid" => "key1", "n" => "certificate 1"}, kid: "key1"},
             Certificates.find(result, "key1")
           )
  end
end
