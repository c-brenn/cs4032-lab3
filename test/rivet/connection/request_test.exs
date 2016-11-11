defmodule Rivet.Connection.RequestTest do
  alias Rivet.Connection.Request
  use ExUnit.Case

  describe "parse/1" do
    test "sets the type of the request correctly" do
      echo = "HELO foo\n"
      shutdown = "KILL_SERVICE-\n"

      assert Request.parse(echo).type == :echo
      assert Request.parse(shutdown).type == :shutdown
    end

    test "it parses the parameters and sets them correctly" do
      req = """
      JOIN_CHATROOM: foo
      CLIENT_IP: 127.0.0.1
      CLIENT_PORT: 8080
      CLIENT_NAME: bar
      this that
      """

      assert Request.parse(req).params ==
        %{
          "join_chatroom" => "foo",
          "client_ip" => "127.0.0.1",
          "client_port" => "8080",
          "client_name"=> "bar"
        }
    end
  end
end
