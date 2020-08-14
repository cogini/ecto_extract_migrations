defmodule EctoExtractMigrations.Commands.CreateView do
  @app :ecto_extract_migrations

  def type, do: :create_view
  defdelegate parse(sql), to: EctoExtractMigrations.Parsers.CreateView
  defdelegate parse(sql, state), to: EctoExtractMigrations.Parsers.CreateView
  defdelegate match(sql), to: EctoExtractMigrations.Parsers.CreateView

  @spec file_name(map, Keyword.t) :: binary
  def file_name(data, bindings)
  def file_name(%{name: [schema, name]}, _bindings), do: "view_#{schema}_#{name}.exs"
  def file_name(%{name: name}, _bindings), do: "view_#{name}.exs"

  def migration(data, bindings) do
    Mix.shell().info("view #{data[:name]}")

    [schema, name] = data.name
    bindings = Keyword.merge(bindings, [
      name: name,
      schema: schema,
      module_name: "#{Macro.camelize(schema)}.#{Macro.camelize(name)}",
      sql: data[:sql]
    ])

    template_dir = Application.app_dir(@app, ["priv", "templates"])
    template_path = Path.join(template_dir, "view.eex")
    EctoExtractMigrations.eval_template(template_path, bindings)
  end
end
