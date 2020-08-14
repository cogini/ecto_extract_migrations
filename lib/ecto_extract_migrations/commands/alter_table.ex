defmodule EctoExtractMigrations.Commands.AlterTable do
  def type, do: :alter_table

  defdelegate parse(sql), to: EctoExtractMigrations.Parsers.AlterTable
  defdelegate parse(sql, state), to: EctoExtractMigrations.Parsers.AlterTable
  defdelegate match(sql), to: EctoExtractMigrations.Parsers.AlterTable
end
