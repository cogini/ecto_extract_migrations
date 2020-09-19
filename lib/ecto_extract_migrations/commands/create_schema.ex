defmodule EctoExtractMigrations.Commands.CreateSchema do
  @moduledoc "Handle CREATE SCHEMA."

  @app :ecto_extract_migrations

  def type, do: :create_schema

  defdelegate parse(sql), to: EctoExtractMigrations.Parsers.CreateSchema
  defdelegate parse(sql, state), to: EctoExtractMigrations.Parsers.CreateSchema
  defdelegate match(sql), to: EctoExtractMigrations.Parsers.CreateSchema

  @spec file_name(map, Keyword.t) :: binary
  def file_name(data, _bindings), do: "schema_#{data.name}.exs"

  @spec migration(map, Keyword.t) :: {:ok, binary} | {:error, term}
  def migration(data, bindings) do
    name = data.name

    repo = bindings[:repo]
    module_name = Enum.join([
      repo,
      "Migrations",
      "Schema",
      Macro.camelize(name)
    ], ".")

    bindings = Keyword.merge(bindings, [
      module_name: module_name,
      up_sql: data[:sql],
      down_sql: "DROP SCHEMA IF EXISTS #{name}"
    ])

    template_dir = Application.app_dir(@app, ["priv", "templates"])
    template_path = Path.join(template_dir, "execute_sql.eex")
    EctoExtractMigrations.eval_template(template_path, bindings)
  end
end
