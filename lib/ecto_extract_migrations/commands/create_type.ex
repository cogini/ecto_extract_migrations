defmodule EctoExtractMigrations.Commands.CreateType do
  @app :ecto_extract_migrations

  def type, do: :create_type
  defdelegate parse(sql), to: EctoExtractMigrations.Parsers.CreateType
  defdelegate parse(sql, state), to: EctoExtractMigrations.Parsers.CreateType
  defdelegate match(sql), to: EctoExtractMigrations.Parsers.CreateType

  def file_name(data, _bindings) do
    name = Enum.join(data.name, "_")
    "type_#{name}.exs"
  end

  def migration(data, bindings) do
    [schema, name] = data.name
    bindings = Keyword.merge(bindings, [
      name: name,
      schema: schema,
      module_name: "#{Macro.camelize(schema)}.#{Macro.camelize(name)}",
      sql: data[:sql]
    ])

    template_dir = Application.app_dir(@app, ["priv", "templates"])
    template_path = Path.join(template_dir, "type.eex")
    EctoExtractMigrations.eval_template(template_path, bindings)
  end
end
