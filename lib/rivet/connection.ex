defmodule Rivet.Connection do
  alias Rivet.{
    Connection,
    Connection.Request,
    Connection.Response,
    Room
  }
  use GenServer
  require Logger

  defstruct [:socket, :rooms]

  @ip_address Application.get_env(:rivet, :ip_address)
  @port Application.get_env(:rivet, :port)
  @student_number 13327472
  @response_suffix ~s(IP:#{@ip_address}\nPort:#{@port}\nStudentID:#{@student_number}\n)

  def start_link(socket) do
    GenServer.start_link(__MODULE__, socket)
  end

  def init(socket) do
    log_socket_event(socket, "Connection opened")
    {:ok, %Connection{socket: socket, rooms: %{}}}
  end

  def close(pid) do
    GenServer.cast(pid, :close_connection)
  end

  def send_message(connection, message) do
    GenServer.cast(connection, {:send, message})
  end

  def handle_info({:tcp, _, msg}, conn) do
    msg
    |> Request.parse()
    |> log_request(conn.socket)
    |> handle_tcp(conn)
  end
  def handle_info(msg, conn) do
    log_socket_event(conn.socket, "Un-handled info: #{inspect(msg)}")
    {:noreply, conn}
  end

  defp handle_tcp(%Request{type: :echo, body: msg}, conn) do
    [msg, @response_suffix]
    |> send_packet(conn.socket)
    {:noreply, conn}
  end

  defp handle_tcp(%Request{type: :join, params: params}, conn) do
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

  defp handle_tcp(%Request{type: :leave, params: params}, conn) do
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

  defp handle_tcp(%Request{type: :chat, params: params}, conn) do
    room_id = params["chat"] |> String.to_integer
    message = params["message"]
    name    = params["client_name"]

    Room.broadcast(room_id, message, name)

    {:noreply, conn}
  end

  defp handle_tcp(%Request{type: :disconnect, params: params}, conn) do
    client_name = params["client_name"]
    msg = "#{client_name} has left this chatroom."

    conn.rooms
    |> Enum.each(fn {room_id, _} ->
      Room.broadcast(room_id, msg, client_name)
    end)
    Connection.close(self())

    {:noreply, %{conn| rooms: %{}}}
  end

  defp handle_tcp(%Request{type: :shutdown}, conn) do
    Connection.Registry.terminate_open_connections()
    {:noreply, conn}
  end

  defp handle_tcp(_, conn), do: {:noreply, conn}

  def handle_cast({:send, message}, conn) do
    :gen_tcp.send(conn.socket, message)
    log_response(conn.socket, message)
    {:noreply, conn}
  end

  def handle_cast(:close_connection, conn) do
    {:stop, {:shutdown, :close_connection}, conn}
  end

  def send_packet(data, socket) do
    log_response(socket, data)
    :gen_tcp.send(socket, data)
  end

  def terminate(_, conn) do
    log_socket_event(conn.socket, "Connection closed")
    :gen_tcp.close(conn.socket)
  end

  defp log_response(socket, response) do
    msg = """
    ------------------------
    #{response}
    ------------------------
    """
    log_socket_event(socket, ["Sent response:\n", msg])
  end

  defp log_socket_event(socket, message) do
    {:ok, {{ip1, ip2, ip3, ip4}, port}} = :inet.peername(socket)
    ip = "#{ip1}.#{ip2}.#{ip3}.#{ip4}"
    Logger.info([ip, ":#{port} -- ", message])
  end

  defp log_request(%Request{} = r, socket) do
    msg = """
    ------------------------
    #{r}
    ------------------------
    """
    log_socket_event(socket, ["Received request:\n", msg])
    r
  end
end
