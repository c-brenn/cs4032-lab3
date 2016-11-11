defmodule Rivet.Room.Members do
  @name __MODULE__

  def register(room_id, join_id) do
    Registry.register(@name, room_id, join_id)
  end

  def unregister(room_id) do
    Registry.unregister(@name, room_id)
  end

  def dispatch(room_id, function) do
    Registry.dispatch(@name, room_id, function)
  end
end
