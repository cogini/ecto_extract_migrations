defmodule EctoExtractMigrations.Schema do

  @app :ecto_extract_migrations

  def create_migration(data, bindings) do
    Mix.shell().info("#{data[:type]} #{data[:name]}")

    schema = data.name
    bindings = Keyword.merge(bindings, [
      schema: schema,
      module_name: Macro.camelize(schema)
    ])

    template_dir = Application.app_dir(@app, ["priv", "templates"])
    template_path = Path.join(template_dir, "schema.eex")
    EctoExtractMigrations.eval_template(template_path, bindings)
  end

  def migration_filename(prefix, data) do
    "#{prefix}_schema_#{data.name}.exs"
  end

end
