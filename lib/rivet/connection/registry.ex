defmodule Rivet.Connection.Registry do
  alias Rivet.Connection
  use GenServer

  @name __MODULE__

  # == Public API ==

  def start_link() do
    GenServer.start_link(__MODULE__, nil, name: @name)
  end

  def connection_count() do
    %{ workers: n } = Supervisor.count_children(Rivet.Connection.Supervisor)
    n
  end

  def register_listener(socket) do
    GenServer.cast(@name, {:register_listener, socket})
  end

  def terminate_open_connections() do
    GenServer.cast(@name, :terminate_open_connections)
  end

  # == GenServer API ==

  def handle_cast({:register_listener, socket}, _) do
    {:noreply, socket}
  end

  def handle_cast(:terminate_open_connections, nil), do: {:noreply, nil}
  def handle_cast(:terminate_open_connections, listener) do
    listener |> :gen_tcp.close()
    Supervisor.which_children(Rivet.Connection.Supervisor)
    |> Enum.each(fn {_, child, :worker, [Rivet.Connection]} ->
      Connection.close(child)
    end)
    System.halt
    {:noreply, nil}
  end
end
