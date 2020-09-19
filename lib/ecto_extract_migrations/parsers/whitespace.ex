defmodule EctoExtractMigrations.Parsers.Whitespace do
  @moduledoc "Parser for SQL whitespace."

  def match(line) do
    if Regex.match?(~r/^\s*$/, line) do
      {:ok, ""}
    else
      {:error, "no match"}
    end
  end

end
