defmodule EctoExtractMigrations.Commands.CreateTrigger do

  def type, do: :create_trigger
  defdelegate parse(sql), to: EctoExtractMigrations.Parsers.CreateTrigger
  defdelegate match(sql), to: EctoExtractMigrations.Parsers.CreateTrigger

  # https://www.postgresql.org/docs/current/sql-droptrigger.html

  # %{name: "chat_message_update"}
  # CREATE TRIGGER chat_message_update BEFORE UPDATE ON chat.message FOR EACH ROW EXECUTE PROCEDURE public.chat_update_timestamp();

  def file_name(data, _bindings), do: "create_trigger_#{data.name}.exs"

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
