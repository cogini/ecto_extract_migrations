defmodule EctoExtractMigrations.Parsers.Whitespace do
  import NimbleParsec

  alias EctoExtractMigrations.Parsers.Common

  whitespace = Common.whitespace()

  defparsec :parsec_whitespace, whitespace

  def parse(line) do
    case parsec_whitespace(line) do
      # {:ok, [value], _, _, _, _} -> {:ok, value}
      {:ok, [_value], _, _, _, _} -> {:ok, ""}
      error -> error
    end
  end

  def match(line), do: parse(line)
end

