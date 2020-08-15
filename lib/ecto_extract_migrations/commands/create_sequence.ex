defmodule EctoExtractMigrations.Commands.CreateSequence do
  @app :ecto_extract_migrations

  require EEx

  @migration_statement """
      execute(
      \"\"\"
      <%= Regex.replace(~r/^/m, sql, "  ") %>
      \"\"\", "DROP SEQUENCE IF EXISTS <%= schema %>.<%= name %>")
  """

  def type, do: :create_sequence
  defdelegate parse(sql), to: EctoExtractMigrations.Parsers.CreateSequence
  defdelegate parse(sql, state), to: EctoExtractMigrations.Parsers.CreateSequence
  defdelegate match(sql), to: EctoExtractMigrations.Parsers.CreateSequence

  @spec file_name(map, Keyword.t) :: binary
  def file_name(data, bindings)
  def file_name(%{name: [schema, name]}, _bindings), do: "sequence_#{schema}_#{name}.exs"
  def file_name(%{name: name}, _bindings), do: "sequence_#{name}.exs"

  def migration(data, bindings) do
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

  EEx.function_from_string(:def, :migration_statement, @migration_statement, [:sql, :schema, :name])

  def migration_combine(statements, bindings) do
    bindings = Keyword.merge([module_name: "Sequences", sequences: statements], bindings)
    template_dir = Application.app_dir(@app, ["priv", "templates"])
    template_path = Path.join(template_dir, "sequences.eex")
    EctoExtractMigrations.eval_template(template_path, bindings)
  end
end
