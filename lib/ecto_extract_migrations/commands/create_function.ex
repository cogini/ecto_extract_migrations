defmodule EctoExtractMigrations.Commands.CreateFunction do
  @app :ecto_extract_migrations

  def type, do: :create_function
  defdelegate parse(sql), to: EctoExtractMigrations.Parsers.CreateFunction
  defdelegate parse(sql, state), to: EctoExtractMigrations.Parsers.CreateFunction
  defdelegate match(sql), to: EctoExtractMigrations.Parsers.CreateFunction

  def file_name(data, _bindings), do: "function_#{data.name}.exs"

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
