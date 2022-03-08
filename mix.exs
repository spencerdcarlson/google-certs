defmodule GoogleCerts.MixProject do
  use Mix.Project

  def project do
    [
      app: :google_certs,
      version: "1.0.0-alpha",
      elixir: "~> 1.9",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      # Docs
      name: "Google Certificates",
      source_url: "https://github.com/spencerdcarlson/google-certs",
      homepage_url: "https://github.com/spencerdcarlson/google-certs",
      docs: docs_config(),
      package: package()
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp description do
    """
    A GenServer that stores and caches Google's Public Certificates.
    """
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {GoogleCerts.Application, []}
    ]
  end

  def docs_config do
    [
      extras: ["README.md"],
      main: "readme"
    ]
  end

  def package do
    [
      files: ~w(LICENSE* README* lib mix.exs .formatter.exs),
      maintainers: ["Spencer Carlson"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/spencerdcarlson/google-certs"
      }
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:dialyxir, "~> 1.1", only: [:dev], runtime: false},
      {:jason, "~> 1.0"},
      {:hackney, "~> 1.15"},
      {:ex_doc, "~> 0.21", only: :dev, runtime: false},
      {:credo, "~> 1.3", only: [:dev, :test], runtime: false},
      {:mox, "~> 1.0", only: :test}
    ]
  end
end
