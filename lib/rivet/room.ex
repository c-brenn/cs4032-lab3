defmodule Rivet.Room do
  alias __MODULE__
  alias Rivet.Connection

  def join(room_name) do
    room_id = Room.Registry.lookup_or_create(room_name)
    join_id = generate_join_id()
    Room.Members.register(room_id, join_id)
    {:ok, join_id, room_id}
  end

  def broadcast(room_id, message, client_name) do
    raw_message = [chat: room_id, client_name: client_name, message: message]
    encoded_message = Connection.Response.encode(raw_message)

    Room.Members.dispatch(room_id, fn members ->
      for { connection, _ } <- members do
        Connection.send_message(connection, encoded_message)
      end
    end)
  end

  def leave(room_id) do
    Room.Members.unregister(room_id)
  end

  defp generate_join_id(), do: :erlang.unique_integer()
end
