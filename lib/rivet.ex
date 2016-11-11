defmodule Rivet do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false
    listener_worker = if Application.get_env(:rivet, :listener_enabled, false),
      do: [worker(Task, [Rivet.Listener, :init, []], restart: :temporary)],
      else: []

    children = listener_worker ++ [
      worker(Rivet.Connection.Registry, []),
      supervisor(Rivet.Connection.Supervisor, [])
    ]

    opts = [strategy: :one_for_one, name: Rivet.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
