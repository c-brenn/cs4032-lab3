defmodule Rivet.Connection.Request do
  alias __MODULE__
  defstruct [:type, :params, :body]

  @parameter_regex ~r/[A-Z_]+: \S+/

  def parse(str) do
    %Request{body: str}
    |> set_request_type()
    |> set_parameters()
  end

  defp set_request_type(%Request{body: body} = req) do
    %{req| type: identify_request_type(body)}
  end

  defp identify_request_type("HELO"<>_), do: :echo
  defp identify_request_type("KILL_SERVICE"<>_), do: :shutdown
  defp identify_request_type("JOIN_CHATROOM"<>_), do: :join
  defp identify_request_type("LEAVE_CHATROOM"<>_), do: :leave
  defp identify_request_type("CHAT"<>_), do: :chat
  defp identify_request_type("DISCONNECT"<>_), do: :disconnect
  defp identify_request_type(_), do: :unkown

  defp set_parameters(%Request{type: :echo} = req), do: req
  defp set_parameters(%Request{type: :shutdown} = req), do: req
  defp set_parameters(%Request{type: :disconnect} = req), do: req
  defp set_parameters(%Request{type: :unkown} = req), do: req
  defp set_parameters(%Request{body: body} = req) do
    %{req| params: parse_parameters(body)}
  end

  defp parse_parameters(str) do
    str
    |> String.split("\n", trim: true)
    |> Enum.filter(&(String.match?(&1, @parameter_regex)))
    |> Enum.reduce(%{}, fn(string, params) ->
      [key, value] = String.split(string, ": ")
      Map.put(params, String.downcase(key), value)
    end)
  end

  defimpl String.Chars, for: Request do
    def to_string(%{type: t, body: b, params: p}) do
      """
      type: #{t}
      body: #{inspect(b)}
      params: #{inspect(p)}
      """
    end
  end
end
