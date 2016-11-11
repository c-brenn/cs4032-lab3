defmodule Rivet.Room.Registry do
  @moduledoc """
  Responsible for mapping room names to room ids. Implemented as a named ets table owned by a GenServer.
  """
  use GenServer

  @name __MODULE__

  def start_link do
    GenServer.start_link(__MODULE__, :ok, name: @name)
  end

  def init(:ok) do
    table = :ets.new(@name, [:set, :named_table, :public])
    {:ok, table}
  end

  def lookup_or_create(room_name) do
    case :ets.lookup(@name, room_name) do
      [] -> create(room_name)
      [{^room_name, room_id}] -> room_id
    end
  end

  defp create(room_name) do
    room_id = :erlang.unique_integer
    :ets.insert(@name, {room_name, room_id})
    room_id
  end
end
