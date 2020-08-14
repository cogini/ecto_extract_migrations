defmodule EctoExtractMigrations.Commands.AlterTable do
  @app :ecto_extract_migrations

  @migration_statement """
      execute(
      \"\"\"
      <%= Regex.replace(~r/^/m, sql, "  ") %>
      \"\"\")
  """

  require EEx
  def type, do: :alter_table

  defdelegate parse(sql), to: EctoExtractMigrations.Parsers.AlterTable
  defdelegate parse(sql, state), to: EctoExtractMigrations.Parsers.AlterTable
  defdelegate match(sql), to: EctoExtractMigrations.Parsers.AlterTable

  EEx.function_from_string(:def, :migration_statement, @migration_statement, [:sql, :schema, :name])

  def migration_combine(statements, bindings) do
    bindings = Keyword.merge([module_name: "AlterTable", statements: statements], bindings)
    template_dir = Application.app_dir(@app, ["priv", "templates"])
    template_path = Path.join(template_dir, "alter_tables.eex")
    EctoExtractMigrations.eval_template(template_path, bindings)
  end
end
