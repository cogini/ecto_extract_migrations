defmodule EctoExtractMigrations.Commands.CreateView do
  @moduledoc "Handle CREATE VIEW."

  @app :ecto_extract_migrations

  def type, do: :create_view

  defdelegate parse(sql), to: EctoExtractMigrations.Parsers.CreateView
  defdelegate parse(sql, state), to: EctoExtractMigrations.Parsers.CreateView
  defdelegate match(sql), to: EctoExtractMigrations.Parsers.CreateView

  @spec file_name(map, Keyword.t) :: binary
  def file_name(data, bindings)
  def file_name(%{name: [schema, name]}, _bindings), do: "view_#{schema}_#{name}.exs"
  def file_name(%{name: name}, _bindings), do: "view_#{name}.exs"

  @spec migration(map, Keyword.t) :: {:ok, binary} | {:error, term}
  def migration(data, bindings) do
    [schema, name] = data.name
    module_name = Enum.join([
      bindings[:repo],
      "Migrations",
      "View",
      Macro.camelize(schema),
      Macro.camelize(name)
    ], ".")

    bindings = Keyword.merge(bindings, [
      module_name: module_name,
      up_sql: data[:sql],
      down_sql: "DROP VIEW IF EXISTS #{schema}.#{name}"
    ])

    template_dir = Application.app_dir(@app, ["priv", "templates"])
    template_path = Path.join(template_dir, "execute_sql.eex")
    EctoExtractMigrations.eval_template(template_path, bindings)
  end
end
