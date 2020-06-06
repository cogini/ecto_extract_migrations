defmodule EctoExtractMigrations.Migrations.ForeignKey do
  alias EctoExtractMigrations.Execute

  # %{
  #   action: :add_table_constraint,
  #   columns: ["user_id"],
  #   table: ["chat", "assignment"],
  #   constraint_name: "assignment_care_taker_id_fkey",
  #   references_column: ["id"],
  #   references_table: ["chat", "user"],
  #   type: :foreign_key,
  # }

  # ALTER TABLE ONLY chat.assignment
  #     ADD CONSTRAINT assignment_care_taker_id_fkey FOREIGN KEY (user_id) REFERENCES chat."user"(id);

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
