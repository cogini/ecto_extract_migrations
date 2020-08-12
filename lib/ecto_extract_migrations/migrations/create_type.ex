defmodule EctoExtractMigrations.Migrations.CreateType do

  @app :ecto_extract_migrations

  def file_name(prefix, %{name: comps}, _bindings) do
    name = Enum.join(comps, "_")
    "#{prefix}_type_#{name}.exs"
  end

  def migration(data, bindings) do
    Mix.shell().info("#{data[:type]} #{data[:name]}")

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
