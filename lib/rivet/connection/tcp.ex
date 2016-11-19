defmodule Rivet.Connection.TCP do
  alias Rivet.Connection.Request
  alias Rivet.Connection

  @callback handle_tcp(request :: Request.t, conn :: Connection.t) ::
    {:noreply, new_state} |
    {:noreply, new_state, timeout | :hibernate} |
    {:stop, reason :: term, new_state} when new_state: term

  defmacro __using__(_) do
    quote do
      use GenServer
      require Logger
      @behaviour Rivet.Connection.TCP

      def start_link(socket) do
        GenServer.start_link(__MODULE__, socket)
      end

      def init(socket) do
        {:ok, {{ip1, ip2, ip3, ip4}, port}} = :inet.peername(socket)
        ip = "#{ip1}.#{ip2}.#{ip3}.#{ip4}"
        state = %Connection {
          socket: socket,
          rooms: %{},
          client_ip: ip,
          client_port: port
        }
        {:ok, state}
      end

      def close(connection) do
        GenServer.cast(connection, :close_connection)
      end

      def send_message(connection, message) do
        GenServer.cast(connection, {:send, message})
      end


      def handle_info({:tcp, _, msg}, conn) do
        msg
        |> Rivet.Connection.Request.parse()
        |> log_request(conn)
        |> handle_tcp(conn)
      end
      def handle_info(_, state), do: {:noreply, state}

      def handle_tcp(_, conn), do: {:noreply, conn}

      def handle_cast({:send, message}, conn) do
        :gen_tcp.send(conn.socket, message)
        {:noreply, conn}
      end

      def handle_cast(:close_connection, conn) do
        {:stop, {:shutdown, :close_connection}, conn}
      end


      def send_packet(data, socket) do
        :gen_tcp.send(socket, data)
      end

      def terminate(_, conn) do
        :gen_tcp.close(conn.socket)
      end

      def log_request(request, conn) do
        type = request.type |> Atom.to_string |> String.upcase
        address = conn.client_ip <> ":#{conn.client_port}"
        Logger.info("#{type} from #{address} :: #{inspect request.params}")
        request
      end

      defoverridable [handle_tcp: 2]
    end
  end
end
