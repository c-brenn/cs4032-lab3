defmodule Rivet.Room.Supervisor do
  use Supervisor

  def start_link() do
    Supervisor.start_link(__MODULE__, [])
  end

  def init([]) do
    children = [
      worker(Rivet.Room.Registry, []),
      supervisor(Registry, [:duplicate, Rivet.Room.Members])
    ]

    supervise(children, strategy: :one_for_all)
  end
end
