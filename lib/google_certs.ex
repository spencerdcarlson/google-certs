defmodule GoogleCerts do
  @moduledoc """
  Context for interfacing with Google's Public certificates.

  For practical usage examples see our documentation on [how to use with the joken library](./readme.html#how-to-use-with-the-joken-library)

  See Google's documentation on
  [verify the integrity of the id token](https://developers.google.com/identity/sign-in/web/backend-auth#verify-the-integrity-of-the-id-token)
  for more details.
  """

  require Logger
  alias GoogleCerts.{Certificate, CertificateCache, Certificates, Client, Client.Response, Env}

  @doc """
  Returns the currently stored `GoogleCerts.Certifcates`.

  ## Examples
      iex> GoogleCerts.get()
      %GoogleCerts.Certifcates{
        algorithm: "RS256",
        certs: [
          %GoogleCerts.Certificate{
            cert: %{
              "alg" => "RS256",
              "e" => "AQAB",
              "kid" => "6fcf413224765156b48768a42fac06496a30ff5a",
              "kty" => "RSA",
              "n" => "1sUr077w2aaSnm08qFmuH1UON9e2n6vDNlUxm6WgM95n0_x1GwWTrhXtd_6U6x6R6m-50mVS_ki2BHZ9Fj3Y9W5zBww_TNyNLp4b1802gbXeGhVtQMcFQQ-hFne5HaTVTi1y6QNbu_3V1NW6nNAbpR_t79l1WzGiN4ilFiYFU0OVjk7isf7Dv3-6Trz9riHBExl34qhriu3x5pfipPT1rf4J6jMroJTEeU6L7zd9k_BwjNtptS8wAenYaK4FENR2gxvWWTX40i548Sh-3Ffprlu_9CZCswCkQCdhTq9lo3DbZYPEcW4aOLBEi3FfLiFm-DNDK_P_gBtNz8gW3VMQ2w",
              "use" => "sig"
            },
            kid: "6fcf413224765156b48768a42fac06496a30ff5a"
          },
          %GoogleCerts.Certificate{
            cert: %{
              "alg" => "RS256",
              "e" => "AQAB",
              "kid" => "257f6a5828d1e4a3a6a03fcd1a2461db9593e624",
              "kty" => "RSA",
              "n" => "kXPOxGSWngQ6Q02jhaJfzSum2FaU5_6e6irUuiwZbgUjyN2Q1VYHwuxq2o-aHqUhNPqf2cyCf2HspYwKAbeK9gFXqScrGLPW5pcquOWOVYUzPw87lBGH2fSxCYH35eB14wfLmF_im8DLTtZsaJvMRbqBgikM8Km2UA9ozjfK6E8pWW91fIT-ZF4Qy5zDkT3yX8EnAIMOuXg43v4t03FwFTyF4D9IET2ri2_n2qDhWTgtxJ0FHk3wG2KXdJIIVy2kUCTzMcZKaamRgUExt3Mu_z-2eyny8b6IdLPEIGF51VCgHebPQXE5iZmLGyw6M_pCApGJUw5GpXi6imo3pOvLjQ",
              "use" => "sig"
            },
            kid: "257f6a5828d1e4a3a6a03fcd1a2461db9593e624"
          }
        ],
        expire: "2020-04-10T03:40:42.616266Z",
        version: 3
      }
  """
  @spec get() :: Certificates.t()
  def get, do: CertificateCache.get()

  @doc """
  Returns the algorithm and certificate for a given kid.

  ## Examples
      iex> GoogleCerts.fetch("257f6a5828d1e4a3a6a03fcd1a2461db9593e624")
      {:ok, "RS256",
        %{
          "alg" => "RS256",
          "e" => "AQAB",
          "kid" => "257f6a5828d1e4a3a6a03fcd1a2461db9593e624",
          "kty" => "RSA",
          "n" => "kXPOxGSWngQ6Q02jhaJfzSum2FaU5_6e6irUuiwZbgUjyN2Q1VYHwuxq2o-aHqUhNPqf2cyCf2HspYwKAbeK9gFXqScrGLPW5pcquOWOVYUzPw87lBGH2fSxCYH35eB14wfLmF_im8DLTtZsaJvMRbqBgikM8Km2UA9ozjfK6E8pWW91fIT-ZF4Qy5zDkT3yX8EnAIMOuXg43v4t03FwFTyF4D9IET2ri2_n2qDhWTgtxJ0FHk3wG2KXdJIIVy2kUCTzMcZKaamRgUExt3Mu_z-2eyny8b6IdLPEIGF51VCgHebPQXE5iZmLGyw6M_pCApGJUw5GpXi6imo3pOvLjQ",
          "use" => "sig"
        }
      }


  """
  @spec fetch(String.t()) :: {:ok, String.t(), map()} | {:error, :cert_not_found}
  def fetch(kid) do
    with certificates = %Certificates{algorithm: algorithm} <- get(),
         %Certificate{cert: cert} <- Certificates.find(certificates, kid) do
      {:ok, algorithm, cert}
    else
      _ -> {:error, :cert_not_found}
    end
  end

  defp client, do: Application.get_env(Env.app(), :client, Client)

  @doc """
  Returns a `GoogleCerts.Certifcates` that is not expired.

  If the provided certificates are not expired, then the same certificates are returned.
  If the provided certificates are expired, then new certificates are retrieved via an HTTP request.
  The certificates returned will always be the same version as the certificates provided.
  """
  @spec refresh(Certificates.t()) :: Certificates.t()
  def refresh(certs = %Certificates{version: version}) do
    if Certificates.expired?(certs) do
      Logger.debug("Certificates are expired. Request new certificates via HTTP.")

      case client().get(version) do
        {:ok, %Response{expiration: exp, cert: cert}} ->
          Logger.debug(
            "Retrieved new certificates (v#{inspect(version)}) via HTTP. Certificates will expire on: #{exp}"
          )

          certs =
            Certificates.new()
            |> Certificates.set_version(version)
            |> Certificates.set_expiration(exp)
            |> add_certificates(cert)

          # Async write updated certs to file (disabled by default)
          Task.Supervisor.start_child(GoogleCerts.TaskSupervisor, fn ->
            CertificateCache.serialize(certs)
          end)

          certs

        error ->
          Logger.error("Error getting Google OAuth2 certificates. Error: " <> inspect(error))
          certs
      end
    else
      Logger.debug("Certificates are not expired.")
      certs
    end
  end

  defp add_certificates(certs = %Certificates{version: 1}, body) do
    Enum.reduce(body, certs, fn {kid, cert}, acc ->
      Certificates.add_cert(acc, kid, cert)
    end)
  end

  defp add_certificates(certs = %Certificates{version: version}, body) when version in 2..3 do
    body
    |> Map.get("keys")
    |> Enum.reduce(certs, fn cert = %{"kid" => kid}, acc ->
      Certificates.add_cert(acc, kid, cert)
    end)
  end
end
