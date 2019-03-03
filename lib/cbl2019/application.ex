defmodule Cbl2019.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    # List all child processes to be supervised
    children = [
      # Starts a worker by calling: Cbl2019.Worker.start_link(arg)
      # {Cbl2019.Worker, arg},
      {Cbl2019.Configuration.Store, []},
      {Cbl2019.Configuration.Fetcher, []},
      {Cbl2019.Provision.ImsiStore, []},
      Supervisor.child_spec({Cbl2019.Diameter.Dia, [%{idx: 0, name: :eir, pname: :eir}]}, id: :eir_0),
      # Test Instance of Mme
      {Cbl2019.Diameter.Mme, []},
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Cbl2019.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
