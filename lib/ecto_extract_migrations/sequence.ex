defmodule EctoExtractMigrations.Sequence do
  require EEx

  @app :ecto_extract_migrations
  @migration_statement """
      execute(
      \"\"\"
      <%= Regex.replace(~r/^/m, sql, "  ") %>
      \"\"\", "drop sequence if exists <%= schema %>.<%= name %>")
  """

  def create_migration(data, bindings) do
    Mix.shell().info("sequence #{data[:name]}")

    [schema, name] = data.name
    bindings = Keyword.merge(bindings, [
      name: name,
      schema: schema,
      module_name: "#{Macro.camelize(schema)}.#{Macro.camelize(name)}",
      sql: data[:sql]
    ])

    template_dir = Application.app_dir(@app, ["priv", "templates"])
    template_path = Path.join(template_dir, "sequence.eex")
    EctoExtractMigrations.eval_template(template_path, bindings)
  end

  def migration_filename(prefix, data) do
    "#{prefix}_sequence_#{data.name}.exs"
  end

  EEx.function_from_string(:def, :create_migration_statement, @migration_statement, [:sql, :schema, :name])

end
