defmodule EctoExtractMigrations.Commands.AlterSequence do
  @moduledoc "Handle ALTER SEQUENCE."

  def type, do: :alter_sequence

  defdelegate parse(sql), to: EctoExtractMigrations.Parsers.AlterSequence
  defdelegate parse(sql, state), to: EctoExtractMigrations.Parsers.AlterSequence
  defdelegate match(sql), to: EctoExtractMigrations.Parsers.AlterSequence
end
