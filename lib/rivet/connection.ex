defmodule Rivet.Connection do
  alias Rivet.{
    Connection,
    Connection.Request,
    Connection.Response,
    Room
  }
  use GenServer
  require Logger

  @ip_address Application.get_env(:rivet, :ip_address)
  @port Application.get_env(:rivet, :port)
  @student_number 13327472
  @response_suffix ~s(IP:#{@ip_address}\nPort:#{@port}\nStudentID:#{@student_number}\n)

  def start_link(socket) do
    GenServer.start_link(__MODULE__, socket)
  end

  def init(socket) do
    {:ok, socket}
  end

  def close(pid) do
    GenServer.cast(pid, :close_connection)
  end

  def send_message(connection, message) do
    GenServer.cast(connection, {:send, message})
  end

  def handle_info({:tcp, _, msg}, socket) do
    msg
    |> Request.parse()
    |> log_request()
    |> handle_tcp(socket)
  end
  def handle_info(_, socket), do: {:noreply, socket}

  defp handle_tcp(%Request{type: :echo, body: msg}, socket) do
    [msg, @response_suffix]
    |> send_packet(socket)
    {:noreply, socket}
  end

  defp handle_tcp(%Request{type: :join, params: params}, socket) do
    room_name   = params["join_chatroom"]
    client_name = params["client_name"]
    {:ok, join_id, room_id} = Room.join(room_name)

    [ joined_chatroom: room_name,
      server_ip: @ip_address,
      port: @port,
      room_ref: room_id,
      join_id: join_id ]
    |> send_packet(socket)

    Room.broadcast(room_id, "#{client_name} has joined this chatroom.", client_name)

    {:noreply, socket}
  end

  defp handle_tcp(%Request{type: :leave, params: params}, socket) do
    join_id = params["join_id"]
    room_id = params["leave_chatroom"] |> String.to_integer
    client_name = params["client_name"]

    Room.leave(room_id)

    [ left_chatroom: room_id, join_id: join_id]
    |> send_packet(socket)

    Room.broadcast(room_id, "#{client_name} has left this chatroom.", client_name)

    {:noreply, socket}
  end

  defp handle_tcp(%Request{type: :chat, params: params}, socket) do
    room_id = params["chat"] |> String.to_integer
    message = params["message"]
    name    = params["client_name"]

    Room.broadcast(room_id, message, name)

    {:noreply, socket}
  end

  defp handle_tcp(%Request{type: :disconnect}, socket) do
    {:stop, {:shutdown, :close_connection}, socket}
  end

  defp handle_tcp(%Request{type: :shutdown}, socket) do
    Connection.Registry.terminate_open_connections()
    {:noreply, socket}
  end

  defp handle_tcp(_, socket), do: {:noreply, socket}

  def handle_cast({:send, message}, socket) do
    :gen_tcp.send(socket, message)
    {:noreply, socket}
  end

  def handle_cast(:close_connection, socket) do
    {:stop, {:shutdown, :close_connection}, socket}
  end

  def send_packet(data, socket) do
    packet = Response.encode(data)
    :gen_tcp.send(socket, packet)
  end

  def terminate(_, socket) do
    :gen_tcp.close(socket)
  end

  defp log_request(%Request{} = r) do
    Logger.info("Received Request: #{r}")
    r
  end
end
