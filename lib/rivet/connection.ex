defmodule Rivet.Connection do
  alias Rivet.{ Connection.Request, Room }
  alias __MODULE__

  defstruct [:socket, :rooms, :client_ip, :client_port]

  @opaque t :: %Connection{
    socket: term,
    rooms: %{ term => term },
    client_ip: String.t,
    client_port: integer
  }

  use Rivet.Connection.TCP

  @ip_address Application.get_env(:rivet, :ip_address)
  @port Application.get_env(:rivet, :port)
  @student_number 13327472
  @response_suffix ~s(IP:#{@ip_address}\nPort:#{@port}\nStudentID:#{@student_number}\n)

  def handle_tcp(%Request{type: :echo, body: msg}, conn) do
    [msg, @response_suffix]
    |> send_packet(conn.socket)
    {:noreply, conn}
  end

  def handle_tcp(%Request{type: :join, params: params}, conn) do
    room_name   = params["join_chatroom"]
    client_name = params["client_name"]
    {:ok, join_id, room_id} = Room.join(room_name)

    """
    JOINED_CHATROOM: #{room_name}
    SERVER_IP: #{@ip_address}
    PORT: #{@port}
    ROOM_REF: #{room_id}
    JOIN_ID: #{join_id}
    """
    |> send_packet(conn.socket)

    Room.broadcast(room_id, "#{client_name} has joined this chatroom.", client_name)

    {:noreply, %{conn| rooms: Map.put(conn.rooms, room_id, join_id)}}
  end

  def handle_tcp(%Request{type: :leave, params: params}, conn) do
    join_id = params["join_id"]
    room_id = params["leave_chatroom"] |> String.to_integer
    client_name = params["client_name"]

    """
    LEFT_CHATROOM: #{room_id}
    JOIN_ID: #{join_id}
    """
    |> send_packet(conn.socket)

    Room.broadcast(room_id, "#{client_name} has left this chatroom.", client_name)
    Room.leave(room_id)

    {:noreply, %{conn| rooms: Map.delete(conn.rooms, room_id)}}
  end

  def handle_tcp(%Request{type: :chat, params: params}, conn) do
    room_id = params["chat"] |> String.to_integer
    message = params["message"]
    name    = params["client_name"]

    Room.broadcast(room_id, message, name)

    {:noreply, conn}
  end

  def handle_tcp(%Request{type: :disconnect, params: params}, conn) do
    client_name = params["client_name"]
    msg = "#{client_name} has left this chatroom."

    for {room_id, _} <- conn.rooms, do: Room.broadcast(room_id, msg, client_name)
    Connection.close(self())

    {:noreply, %{conn| rooms: %{}}}
  end

  def handle_tcp(%Request{type: :shutdown}, conn) do
    Connection.Registry.terminate_open_connections()
    {:noreply, conn}
  end

  def handle_tcp(_, conn), do: {:noreply, conn}
end
