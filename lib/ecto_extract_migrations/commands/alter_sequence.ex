defmodule EctoExtractMigrations.Commands.AlterSequence do

  def type, do: :alter_sequence

  defdelegate parse(sql), to: EctoExtractMigrations.Parsers.AlterSequence
  defdelegate parse(sql, state), to: EctoExtractMigrations.Parsers.AlterSequence
  defdelegate match(sql), to: EctoExtractMigrations.Parsers.AlterSequence
end
