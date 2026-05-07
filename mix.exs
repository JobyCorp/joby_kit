defmodule JobyKit.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/jobycorp/joby_kit"

  def project do
    [
      app: :joby_kit,
      version: @version,
      elixir: "~> 1.16",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs(),
      name: "JobyKit",
      source_url: @source_url
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      {:phoenix_live_view, "~> 1.0"},
      {:phoenix_html, "~> 4.1"},
      {:jason, "~> 1.4"},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp description do
    """
    An opinionated, agentic-first design-system kit for Phoenix + daisyUI apps.
    Ships a manifest behaviour, a discoverable /design page, a JSON manifest at
    /design.json for AI agents, and the daisyUI primitive catalogue.
    """
  end

  defp package do
    [
      maintainers: ["Jody Albritton"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url
      },
      files:
        ~w(lib priv .formatter.exs mix.exs README.md LICENSE CHANGELOG.md)
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "CHANGELOG.md"],
      source_url: @source_url,
      source_ref: "v#{@version}"
    ]
  end
end
