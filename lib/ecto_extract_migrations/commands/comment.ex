defmodule EctoExtractMigrations.Commands.Comment do
  def type, do: :comment
  defdelegate parse(sql), to: EctoExtractMigrations.Parsers.Comment
  defdelegate parse(sql, state), to: EctoExtractMigrations.Parsers.Comment
  defdelegate match(sql), to: EctoExtractMigrations.Parsers.Comment
end
