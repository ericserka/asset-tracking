defmodule AssetTracking.MixProject do
  use Mix.Project

  def project do
    [
      app: :asset_tracking,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
      {:duct, git: "https://github.com/namngh/duct.git"},
      {:tarams, "~> 1.7"},
      {:ex_doc, "~> 0.30.7"},
      {:decimal, "~> 2.1"}
    ]
  end
end
