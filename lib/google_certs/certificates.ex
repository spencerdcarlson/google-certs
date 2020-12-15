defmodule GoogleCerts.CertificateDecodeException do
  defexception message: "Could not decode certificate"
end

defmodule GoogleCerts.Certificate do
  @moduledoc """
  Struct to associate a `kid` to a certificate map.

  kid is the id and cert can either be a map with a pem or a JWK map

  version 1 cert is `%{"pem" => "-----BEGIN CERTIFICATE----- ..."}`
  version 3 cert is `%{"kid" => "53c66aab5...". "e" => "AQAB", ...}`
  """
  alias GoogleCerts.{Certificate, CertificateDecodeException}
  @derive Jason.Encoder
  defstruct kid: nil, cert: nil

  @type t(kid, cert) :: %Certificate{kid: kid, cert: cert}
  @type t :: %Certificate{kid: String.t(), cert: map()}

  @spec decode!(map()) :: t | no_return
  def decode!(%{"kid" => kid, "cert" => cert}) do
    %__MODULE__{kid: kid, cert: cert}
  end

  def decode!(cert) do
    raise CertificateDecodeException,
      message: """
      Could not decode certificate
      Cert must have the following string keys: ["kid", "cert"]
      Provided certificate: #{inspect(cert)}
      """
  end
end

defmodule GoogleCerts.Certificates do
  @moduledoc """
  Struct that holds a list of Google.Oauth2.Certificate structs
  with their expiration time algorithm and version
  """

  alias GoogleCerts.{Certificate, CertificateDecodeException, Certificates}
  @derive Jason.Encoder
  defstruct certs: [], expire: nil, algorithm: "RS256", version: 1

  @type t(certs, expire, algorithm, version) :: %Certificates{
          certs: certs,
          expire: expire,
          algorithm: algorithm,
          version: version
        }
  @type t :: %Certificates{
          certs: list(Certificate.t()),
          expire: DateTime.t(),
          algorithm: String.t(),
          version: integer
        }

  @doc """
  Returns true if `expire` is is less than the current UTC time.
  """
  @spec expired?(Certificates.t()) :: boolean
  def expired?(%__MODULE__{expire: %DateTime{} = expire}) do
    DateTime.compare(DateTime.utc_now(), expire) != :lt
  end

  def expired?(_), do: true

  @spec set_expiration(Certificates.t(), DateTime.t()) :: Certificates.t()
  def set_expiration(struct = %__MODULE__{}, expiration) do
    %__MODULE__{struct | expire: expiration}
  end

  @spec set_version(Certificates.t(), integer) :: Certificates.t()
  def set_version(struct = %__MODULE__{}, version) do
    %__MODULE__{struct | version: version}
  end

  @spec add_cert(Certificates.t(), String.t(), map) :: Certificates.t()
  def add_cert(struct = %__MODULE__{certs: certs, version: 1}, kid, cert) do
    %__MODULE__{
      struct
      | certs: [%Certificate{kid: kid, cert: %{"pem" => cert}} | certs]
    }
  end

  def add_cert(struct = %__MODULE__{certs: certs, version: v}, kid, cert) when v in 2..3 do
    %__MODULE__{
      struct
      | certs: [%Certificate{kid: kid, cert: cert} | certs],
        algorithm: Map.get(cert, "alg")
    }
  end

  @doc """
  Returns a `GoogleCerts.Certificate` for a given kid that is in `certs`
  """
  @spec find(Certificates.t(), String.t()) :: Certificate.t()
  def find(%__MODULE__{certs: certs}, kid) do
    Enum.find(certs, fn %Certificate{kid: id} -> id == kid end)
  end

  @doc """
  Returns a `GoogleCerts.Certificates` from the provided json or raw elixir map
  """
  @spec decode!(String.t() | map) :: Certificates.t() | no_return
  def decode!(json) when is_bitstring(json), do: json |> Jason.decode!() |> decode!()

  def decode!(%{
        "algorithm" => algorithm,
        "certs" => certs,
        "expire" => expire,
        "version" => version
      }) do
    {:ok, expire, 0} = DateTime.from_iso8601(expire)

    %__MODULE__{
      certs: Enum.map(certs, &Certificate.decode!/1),
      expire: expire,
      algorithm: algorithm,
      version: version
    }
  end

  def decode!(arg) do
    raise CertificateDecodeException,
      message: "The provided arg does not conform to the required structure. arg: #{inspect(arg)}"
  end
end
