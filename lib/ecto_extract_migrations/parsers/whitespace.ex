defmodule EctoExtractMigrations.Parsers.Whitespace do
  import NimbleParsec

  alias EctoExtractMigrations.Parsers.Common

  whitespace = Common.whitespace()

  defparsec :parsec_parse, whitespace

  def parse(line) do
    case parsec_parse(line) do
      # {:ok, [value], _, _, _, _} -> {:ok, value}
      {:ok, [_value], _, _, _, _} -> {:ok, ""}
      error -> error
    end
  end

  def match(line), do: parse(line)

  def tag, do: :whitespace
end
