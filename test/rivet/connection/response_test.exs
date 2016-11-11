defmodule Rivet.Connection.ResponseTest do
  alias Rivet.Connection.Response
  use ExUnit.Case

  describe "encode/1" do
    test "does nothing to strings" do
      assert Response.encode("foo") == "foo"
    end

    test "encodes maps in the format - key1: value1\nkey2: value2..." do
      data = [ joined_chatroom: "foo", room_ref: 1, join_id: 1 ]
      assert Response.encode(data) |> IO.chardata_to_string ==
      "JOINED_CHATROOM: foo\nROOM_REF: 1\nJOIN_ID: 1\n\n"
    end
  end
end
