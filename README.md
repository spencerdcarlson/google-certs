# Google Certificates

A Lightweight GenServer that stores and caches Google's Public Certificates. 


The Google Certificates library makes it easy to verify and validate a [JWT](https://tools.ietf.org/html/rfc7519) issued by Google.
See the [how to use with the joken library](./readme.html#how-to-use-with-the-joken-library) section below for an example on how to accomplish this using this library combined with the [Joken](https://hexdocs.pm/joken/introduction.html) library.


For more details, see Google's [backend-auth](https://developers.google.com/identity/sign-in/web/backend-auth) documentation, specifically the [verify the integrity of the id token](https://developers.google.com/identity/sign-in/web/backend-auth#verify-the-integrity-of-the-id-token) section.

The default behavior is to use the `JWK` format ([/oauth2/v3/certs](https://www.googleapis.com/oauth2/v3/certs)) for certificates, but the `PEM` ([/oauth2/v1/certs](https://www.googleapis.com/oauth2/v1/certs)) format can be used if specified.


## Installation

This package can be installed
by adding `google_certs` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:google_certs, "~> 0.1"}
  ]
end
```

## Usage
`GoogleCerts.CertificateCache` is an [Agent](https://hexdocs.pm/elixir/Agent.html) 
so you can simply add it to your supervision tree and Google's certificates will be downloaded and cached on startup.
```elixir
  use Application
  alias GoogleCerts.CertificateCache
  
  def start(_type, _args) do
    children = [
      CertificateCache
    ]

    opts = [strategy: :one_for_one, name: Directory.Supervisor]
    Supervisor.start_link(children, opts)
  end
```

There are three publicity available functions that are helpful.
1. `GoogleCerts.get/0`- Get cached certificates
1. `GoogleCerts.fetch/1` -  Get a certificate by it's kid (useful with `Joken.peek_header/1` to and `Joken.Signer.create/3` to create a signer)
1. `GoogleCerts.refresh/1` - Refresh a `GoogleCerts.Certificates` struct if the certificates are expired. Intended for internal use.

```elixir
iex> GoogleCerts.get()                                              # get all certificates
iex> GoogleCerts.fetch("257f6a5828d1e4a3a6a03fcd1a2461db9593e624")  # get a certificate by its kid
iex> GoogleCerts.refresh(%GoogleCerts.Certificates{})               # refresh a set of certificates if they are expired
```

## How to use with the [Joken](https://hexdocs.pm/joken/introduction.html) library

1. Create a custom verify hook
1. Register your custom verify hook with your JWTManager (custom module that `use Joken.Config` )
1. Use your JWTManager to verify and validate a JWT issued from Google.
   1. See [ueberauth](https://hex.pm/packages/ueberauth) and [ueberauth_google](https://hex.pm/packages/ueberauth_google) packages for retrieving a JWT from Google as part of your authentication. 

Create a custom verify hook
```elixir
defmodule Crypto.VerifyHook do
  @moduledoc false

  use Joken.Hooks

  @impl true
  def before_verify(_options, {jwt, %Joken.Signer{} = _signer}) do
    with {:ok, %{"kid" => kid}} <- Joken.peek_header(jwt),
         {:ok, algorithm, key} <- GoogleCerts.fetch(kid) do
      {:cont, {jwt, Joken.Signer.create(algorithm, key)}}
    else
      error -> {:halt, {:error, :no_signer}}
    end
  end
end
```

Register your custom verify hook with your JWTManager
```elixir
defmodule Crypto.JWTManager do
  @moduledoc false

  use Joken.Config, default_signer: nil

  @iss "https://accounts.google.com"
  
  # your google client id (usually ends in *.apps.googleusercontent.com)
  defp aud, do: Application.get_env(:my_app, :google_client_id) 

  # reference your custom verify hook here
  add_hook(Crypto.VerifyHook) 

  @impl Joken.Config
  def token_config do
    default_claims(skip: [:aud, :iss])
    |> add_claim("iss", nil, &(&1 == @iss))
    |> add_claim("aud", nil, &(&1 == aud()))
  end
end
```

Use your JWTManager to verify and validate a JWT issued from Google
```elixir
iex> jwt = "eyJhbGciOiJSUzI1..."
iex> {:ok, claims} = JWTManager.verify_and_validate(jwt)
```

## Configuration (Optional)
```elixir
# config/config.exs
config :google_certs, version: 1 # Use PEM format instead of JWK format. defaults to 3 for JWK
```

