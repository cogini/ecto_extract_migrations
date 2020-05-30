defmodule AlterTableTest do
  use ExUnit.Case

  alias EctoExtractMigrations.AlterTable

  test "primary_key" do
    expected = %{
      action: :add_constraint,
      constraint_name: "assignment_pkey",
      primary_key: ["id"],
      table_name: ["chat", "assignment"]
    }
    assert [expected] == value(AlterTable.parse("""
    ALTER TABLE ONLY chat.assignment
        ADD CONSTRAINT assignment_pkey PRIMARY KEY (id);
    """))

    expected = %{
      action: :add_constraint,
      constraint_name: "message_pkey",
      primary_key: ["id"],
      table_name: ["chat", "message"]
    }
    assert [expected] == value(AlterTable.parse("""
    ALTER TABLE ONLY chat.message
        ADD CONSTRAINT message_pkey PRIMARY KEY (id);
    """))

    expected = %{
      action: :add_constraint,
      constraint_name: "message_upload_pkey",
      primary_key: ["uuid"],
      table_name: ["chat", "message_upload"]
    }
    assert [expected] == value(AlterTable.parse("""
    ALTER TABLE ONLY chat.message_upload
        ADD CONSTRAINT message_upload_pkey PRIMARY KEY (uuid);
    """))

    expected = %{
      action: :add_constraint,
      constraint_name: "pending_chunk_pkey",
      primary_key: ["uuid", "chunk"],
      table_name: ["chat", "pending_chunk"]
    }
    assert [expected] == value(AlterTable.parse("""
    ALTER TABLE ONLY chat.pending_chunk
        ADD CONSTRAINT pending_chunk_pkey PRIMARY KEY (uuid, chunk);
    """))
  end

  def value({:ok, value, "", _, _, _}), do: value
  def value({:error, value, _, _, _, _}), do: value
end
