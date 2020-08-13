defmodule EctoExtractMigrations.Commands.CreateSchema do
  @app :ecto_extract_migrations

  def type, do: :create_schema
  defdelegate parse(sql), to: EctoExtractMigrations.Parsers.CreateSchema
  defdelegate match(sql), to: EctoExtractMigrations.Parsers.CreateSchema

  def file_name(data, _bindings), do: "schema_#{data.name}.exs"

  def migration(data, bindings) do
    schema = data.name
    bindings = Keyword.merge(bindings, [
      schema: schema,
      module_name: Macro.camelize(schema)
    ])

    template_dir = Application.app_dir(@app, ["priv", "templates"])
    template_path = Path.join(template_dir, "schema.eex")
    EctoExtractMigrations.eval_template(template_path, bindings)
  end

end
