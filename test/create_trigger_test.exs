defmodule CreateTriggerTest do
  use ExUnit.Case

  alias EctoExtractMigrations.Parsers.CreateTrigger

  test "create_trigger" do
    sql = """
    CREATE TRIGGER chat_message_update BEFORE UPDATE ON chat.message FOR EACH ROW EXECUTE PROCEDURE public.chat_update_timestamp();
    """
    expected = %{name: "chat_message_update"}
    assert {:ok, expected} == CreateTrigger.parse(sql)
  end

end
