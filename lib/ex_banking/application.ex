defmodule ExBanking.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Starts a worker by calling: ExBanking.Worker.start_link(arg)
      # {ExBanking.Worker, arg}
    ]

    opts = [strategy: :one_for_one, name: ExBanking.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
