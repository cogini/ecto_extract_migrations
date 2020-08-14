defmodule EctoExtractMigrations.Parsers.Whitespace do

  def match(line) do
    if Regex.match?(~r/^\s*$/, line) do
      {:ok, ""}
    else
      {:error, "no match"}
    end
  end

end
