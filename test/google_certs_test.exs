defmodule GoogleCertsTest do
  use GoogleCerts.Case
  use ExUnit.Case, async: false

  describe "GoogleCerts.refresh" do
    test "handles version 1 format" do
      with_mocks([
        {:hackney, [],
         [
           get: fn _, _ ->
             {:ok, 200,
              [{"Cache-Control", "public, max-age=19721, must-revalidate, no-transform"}],
              :fake_ref}
           end
         ]},
        {:hackney, [],
         [body: fn _ -> {:ok, ~s({"key1": "certificate 1", "key2": "certificate 2"})} end]}
      ]) do
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
  end

  test "handles version 2 format" do
    with_mocks([
      {:hackney, [],
       [
         get: fn _, _ ->
           {:ok, 200, [{"Cache-Control", "public, max-age=19721, must-revalidate, no-transform"}],
            :fake_ref}
         end
       ]},
      {:hackney, [],
       [body: fn _ -> {:ok, ~s({"keys": [{"kid": "key1", "n": "certificate 1"}]})} end]}
    ]) do
      result = GoogleCerts.refresh(%Certificates{version: 2})

      assert match?(
               %Certificate{cert: %{"kid" => "key1", "n" => "certificate 1"}, kid: "key1"},
               Certificates.find(result, "key1")
             )
    end
  end

  test "handles version 3 format" do
    seconds = 19_721

    with_mocks([
      {:hackney, [],
       [
         get: fn _, _ ->
           {:ok, 200,
            [{"Cache-Control", "public, max-age=#{seconds}, must-revalidate, no-transform"}],
            :fake_ref}
         end
       ]},
      {:hackney, [],
       [body: fn _ -> {:ok, ~s({"keys": [{"kid": "key1", "n": "certificate 1"}]})} end]}
    ]) do
      result = GoogleCerts.refresh(%Certificates{version: 3})
      assert match?(%Certificates{expire: _, version: 3}, result)

      assert DateTime.utc_now()
             |> DateTime.add(seconds, :second)
             |> DateTime.diff(Map.get(result, :expire)) == 0

      assert match?(
               %Certificate{cert: %{"kid" => "key1", "n" => "certificate 1"}, kid: "key1"},
               Certificates.find(result, "key1")
             )
    end
  end
end
