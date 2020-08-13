defmodule EctoExtractMigrations.Commands.Whitespace do
  def type, do: :whitespace
  defdelegate parse(sql), to: EctoExtractMigrations.Parsers.Whitespace
  defdelegate match(sql), to: EctoExtractMigrations.Parsers.Whitespace
end
