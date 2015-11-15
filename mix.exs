defmodule Romeo.Mixfile do
  use Mix.Project

  @version "0.0.0"

  def project do
    [app: :romeo,
     name: "Romeo",
     version: @version,
     elixir: "~> 1.1",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     description: description,
     deps: deps,
     docs: docs,
     package: package]
  end

  def application do
    [applications: [:logger, :connection, :exml],
     mod: {Romeo, []}]
  end

  defp description do
    "An XMPP Client for Elixir"
  end

  defp deps do
    [{:connection, "~> 1.0"},
     {:exml, github: "paulgray/exml"},

     # Docs deps
     {:earmark, "~> 0.1", only: :dev},
     {:ex_doc, "~> 0.10", only: :dev}]
  end

  defp docs do
    [extras: docs_extras,
     main: "extra-readme"]
  end

  defp docs_extras do
    ["README.md"]
  end

  defp package do
    [files: ["lib", "priv", "mix.exs", "README.md", "LICENSE"],
       maintainers: ["Sonny Scroggin"],
       licenses: ["MIT"],
       links: %{"GitHub" => "https://github.com/scrogson/romeo"}]
  end
end
