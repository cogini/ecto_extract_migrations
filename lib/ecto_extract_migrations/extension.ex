defmodule EctoExtractMigrations.Extension do

  @app :ecto_extract_migrations

  def create_migration(data, bindings) do
    Mix.shell().info("#{inspect data}")

    name = data.name
    schema = data.schema

    bindings = Keyword.merge(bindings, [
      name: name,
      schema: schema,
      module_name: "#{Macro.camelize(schema)}.#{Macro.camelize(name)}",
      sql: data[:sql]
    ])

    template_dir = Application.app_dir(@app, ["priv", "templates"])
    template_path = Path.join(template_dir, "extension.eex")
    EctoExtractMigrations.eval_template(template_path, bindings)
  end

  def migration_filename(prefix, data) do
    name = data.name
    schema = data.schema
    "#{prefix}_extension_#{schema}_#{name}.exs"
  end

end
