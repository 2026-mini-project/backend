defmodule MinesweeperBackend.Base85 do
  @moduledoc """
  RFC 1924 (a.k.a. z85-style b85) Base85 codec.

  4 input bytes map to 5 output characters. Each output character is
  `chr(33 + ((n // 85^(4-i)) % 85))` for `i in 0..4`, so the output
  alphabet is printable ASCII starting at `!` (0x21) and ending at
  `~` (0x7E). The minefield bitstring is `size * size` bits, which
  for the default 8x8 board is 64 bits = 8 bytes = a multiple of 4.
  """

  @offset 33

  @alphabet Enum.map(0..84, fn i -> i + @offset end) |> List.to_string()
  @table Map.new(Enum.with_index(String.to_charlist(@alphabet)))

  @doc "Encodes a binary to RFC 1924 Base85. Length must be a multiple of 4."
  @spec encode(binary()) :: String.t()
  def encode(bin) when is_binary(bin) do
    if rem(byte_size(bin), 4) != 0 do
      raise ArgumentError, "Base85.encode input length must be a multiple of 4"
    end

    bin
    |> :binary.bin_to_list()
    |> Enum.chunk_every(4)
    |> Enum.map_join(&encode_chunk/1)
  end

  defp encode_chunk([a, b, c, d]) do
    n = a * 16_777_216 + b * 65_536 + c * 256 + d

    Enum.map_join(0..4, fn i ->
      v = div(n, pow85(4 - i)) |> rem(85)
      <<v + @offset::utf8>>
    end)
  end

  defp pow85(0), do: 1
  defp pow85(1), do: 85
  defp pow85(2), do: 85 * 85
  defp pow85(3), do: 85 * 85 * 85
  defp pow85(4), do: 85 * 85 * 85 * 85

  @doc "Decodes an RFC 1924 Base85 string back to its original binary."
  @spec decode(String.t()) :: {:ok, binary()} | {:error, term()}
  def decode(str) when is_binary(str) do
    cond do
      rem(byte_size(str), 5) != 0 ->
        {:error, :invalid_length}

      true ->
        chars = String.to_charlist(str)

        try do
          decoded =
            chars
            |> Enum.chunk_every(5)
            |> Enum.map(&decode_chunk/1)
            |> IO.iodata_to_binary()

          {:ok, decoded}
        catch
          _, _ -> {:error, :invalid}
        end
    end
  end

  defp decode_chunk(chars) do
    n =
      Enum.reduce(chars, 0, fn c, acc ->
        case Map.fetch(@table, c) do
          {:ok, v} -> acc * 85 + v
          :error -> throw(:invalid)
        end
      end)

    <<n::32-big>>
  end
end
