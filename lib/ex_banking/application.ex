defmodule ExBanking.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {DynamicSupervisor, name: ExBanking.UserSupervisor, strategy: :one_for_one},
      {Registry, keys: :unique, name: Registry.Users}
    ]

    opts = [strategy: :one_for_one, name: ExBanking.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
