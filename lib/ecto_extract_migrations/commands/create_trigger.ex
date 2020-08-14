defmodule EctoExtractMigrations.Commands.CreateTrigger do

  def type, do: :create_trigger
  defdelegate parse(sql), to: EctoExtractMigrations.Parsers.CreateTrigger
  defdelegate parse(sql, state), to: EctoExtractMigrations.Parsers.CreateTrigger
  defdelegate match(sql), to: EctoExtractMigrations.Parsers.CreateTrigger

  # https://www.postgresql.org/docs/current/sql-droptrigger.html

  # %{name: "chat_message_update"}
  # CREATE TRIGGER chat_message_update BEFORE UPDATE ON chat.message FOR EACH ROW EXECUTE PROCEDURE public.chat_update_timestamp();

  @spec file_name(map, Keyword.t) :: binary
  def file_name(data, bindings)
  def file_name(%{name: [schema, name]}, _bindings), do: "trigger_#{schema}_#{name}.exs"
  def file_name(%{name: name}, _bindings), do: "trigger_#{name}.exs"

  def migration(data, bindings) do
    module_name = module_name(data, bindings)
    EctoExtractMigrations.Execute.create_migration(module_name, data.sql)
  end

  @doc "Create module name based on data"
  def module_name(data, bindings) do
    [bindings[:repo], "migrations", "create_trigger"] ++ [data.name]
    |> Enum.map(&Macro.camelize/1)
    |> Module.concat()
  end
end
