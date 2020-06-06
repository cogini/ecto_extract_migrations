defmodule EctoExtractMigrations.Migrations.Unique do
  alias EctoExtractMigrations.Execute

  # %{
  #   action: :add_table_constraint,
  #   constraint_name: "session_token_key",
  #   table: ["chat", "session"],
  #   columns: ["token"],
  #   type: :unique,
  # }

  # ALTER TABLE ONLY chat.session
  #     ADD CONSTRAINT session_token_key UNIQUE (token);

  def file_name(prefix, %{table: [schema, table], columns: columns}, _bindings) do
    "#{prefix}_alter_table_foreign_key_#{schema}_#{table}_#{Enum.join(columns, "_")}.exs"
  end

  def migration(data, bindings) do
    module_name = module_name(data, bindings)
    Execute.create_migration(module_name, data.sql)
  end

  @doc "Create module name based on data"
  def module_name(%{table: [schema, table], columns: columns}, bindings) do
    [bindings[:repo], "migrations", "alter_table", "foreign_key"] ++ [schema, table] ++ columns
    |> Enum.map(&Macro.camelize/1)
    |> Module.concat()
  end
end
