defmodule EctoExtractMigrations.Migrations.CreateSchema do

  @app :ecto_extract_migrations

  def file_name(prefix, %{name: name}, _bindings) do
    "#{prefix}_schema_#{name}.exs"
  end

  def migration(data, bindings) do
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
end
