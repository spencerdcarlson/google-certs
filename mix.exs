defmodule GoogleCerts.MixProject do
  use Mix.Project

  def project do
    [
      app: :google_certs,
      version: "0.1.0",
      elixir: "~> 1.9",
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

  defp description do
    """
    A GenServer that stores and caches Google's Public Certificates.
    """
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
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
        "GitHub" => "https://github.com/spencerdcarlson/google-certs",
        "Docs" => "http://hexdocs.pm/google-certs"
      }
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:jason, "~> 1.0"},
      {:hackney, "~> 1.15"},
      {:ex_doc, "~> 0.21", only: :dev, runtime: false},
      {:credo, "~> 1.3", only: [:dev, :test], runtime: false}
    ]
  end
end
