defmodule Cbl2019.MixProject do
  use Mix.Project

  def project do
    [
      app: :cbl_2019,
      version: "0.1.0",
      elixir: "~> 1.8",
      elixirc_paths: elixirc_paths(Mix.env()),
      erlc_options: [],
      # Let's give our Erlang dependency to the compiler
      erlc_paths: ["deps/minidiadict"],
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :diameter, :minidiadict],
      mod: {Cbl2019.Application, []}
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    IO.puts(Mix.env())
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
      {:ex_doc, "~> 0.18", only: [:dev, :local]},
      {:logger_file_backend, "~> 0.0.10"},
      {:poison, "~> 3.1"},
      { :file_system, "~> 0.2", only: :test },
    ]
    |> Enum.concat(extra_deps(Mix.env()))
  end

  # Sorry, added this in case I cannot access the internet and need to edit deps :)
  defp extra_deps(:local) do
    [
      {:minidiadict, git: "/home/zoten/git_repos/cbl2019 - diameter/minidiadict", branch: "master"},
    ]
  end

  defp extra_deps(env) when env in [:dev] do
    [
      {:minidiadict, git: "https://github.com/zoten/minidiadict", branch: "master"},
    ]
  end

  defp extra_deps(env) when env in [:test] do
    [

    ]
  end

  defp extra_deps(_env) do
    []
  end
end
