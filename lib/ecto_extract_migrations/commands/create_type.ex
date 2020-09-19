defmodule EctoExtractMigrations.Commands.CreateType do
  @moduledoc "Handle CREATE TYPE."

  @app :ecto_extract_migrations

  def type, do: :create_type

  defdelegate parse(sql), to: EctoExtractMigrations.Parsers.CreateType
  defdelegate parse(sql, state), to: EctoExtractMigrations.Parsers.CreateType
  defdelegate match(sql), to: EctoExtractMigrations.Parsers.CreateType

  @spec file_name(map, Keyword.t) :: binary
  def file_name(data, bindings)
  def file_name(%{name: [schema, name]}, _bindings), do: "type_#{schema}_#{name}.exs"
  def file_name(%{name: name}, _bindings), do: "type_#{name}.exs"

  @spec migration(map, Keyword.t) :: {:ok, binary} | {:error, term}
  def migration(data, bindings) do
    [schema, name] = data.name

    module_name = Enum.join([
      bindings[:repo],
      "Migrations",
      "Type",
      Macro.camelize(schema),
      Macro.camelize(name)
    ], ".")

    bindings = Keyword.merge(bindings, [
      module_name: module_name,
      up_sql: data[:sql],
      down_sql: "DROP TYPE IF EXISTS #{schema}.#{name}"
    ])

    template_dir = Application.app_dir(@app, ["priv", "templates"])
    template_path = Path.join(template_dir, "execute_sql.eex")
    EctoExtractMigrations.eval_template(template_path, bindings)
  end
end
