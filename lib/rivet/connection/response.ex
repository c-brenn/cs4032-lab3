defmodule Rivet.Connection.Response do
  def encode(data) when is_binary(data), do: data
  def encode(data) when is_list(data) do
    data
    |> Enum.reduce([], fn(data, acc) -> [acc | [encode_value(data)]] end)
  end

  defp encode_value(string) when is_binary(string), do: string
  defp encode_value({k, value}) do
    key = k |> Atom.to_string() |> String.upcase()
    [key, ": ", encode_value(value), "\n"]
  end
  defp encode_value(x), do: inspect(x)
end
