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
    assert {:ok, expected} == AlterTable.parse("""
    ALTER TABLE ONLY chat.assignment
        ADD CONSTRAINT assignment_pkey PRIMARY KEY (id);
    """)

    expected = %{
      action: :add_constraint,
      constraint_name: "message_pkey",
      primary_key: ["id"],
      table_name: ["chat", "message"]
    }
    assert {:ok, expected} == AlterTable.parse("""
    ALTER TABLE ONLY chat.message
        ADD CONSTRAINT message_pkey PRIMARY KEY (id);
    """)

    expected = %{
      action: :add_constraint,
      constraint_name: "message_upload_pkey",
      primary_key: ["uuid"],
      table_name: ["chat", "message_upload"]
    }
    assert {:ok, expected} == AlterTable.parse("""
    ALTER TABLE ONLY chat.message_upload
        ADD CONSTRAINT message_upload_pkey PRIMARY KEY (uuid);
    """)

    expected = %{
      action: :add_constraint,
      constraint_name: "pending_chunk_pkey",
      primary_key: ["uuid", "chunk"],
      table_name: ["chat", "pending_chunk"]
    }
    assert {:ok, expected} == AlterTable.parse("""
    ALTER TABLE ONLY chat.pending_chunk
        ADD CONSTRAINT pending_chunk_pkey PRIMARY KEY (uuid, chunk);
    """)

    expected = %{
      action: :add_constraint,
      constraint_name: "session_token_key",
      table_name: ["chat", "session"],
      unique: ["token"]
    }
    assert {:ok, expected} == AlterTable.parse("""
    ALTER TABLE ONLY chat.session                                                                                                                                                       ADD CONSTRAINT session_token_key UNIQUE (token);
    """)
  end

  test "column constraint" do
    expected = %{
      action: :set_default,
      table_name: ["chat", "assignment"],
      column_name: "id",
      default: "nextval('chat.assignment_id_seq'::regclass)"
    }
    assert {:ok, expected} == AlterTable.parse("""
    ALTER TABLE ONLY chat.assignment ALTER COLUMN id SET DEFAULT nextval('chat.assignment_id_seq'::regclass);
    """)

  end

  def value({:ok, value, "", _, _, _}), do: value
  def value({:error, value, _, _, _, _}), do: value
end
