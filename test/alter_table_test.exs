defmodule AlterTableTest do
  use ExUnit.Case

  alias EctoExtractMigrations.Parsers.AlterTable

  test "primary_key" do
    expected = %{
      action: :add_table_constraint,
      constraint_name: "assignment_pkey",
      primary_key: ["id"],
      table: ["chat", "assignment"],
      type: :primary_key,
    }
    assert {:ok, expected} == AlterTable.parse("""
    ALTER TABLE ONLY chat.assignment
        ADD CONSTRAINT assignment_pkey PRIMARY KEY (id);
    """)

    expected = %{
      action: :add_table_constraint,
      constraint_name: "message_pkey",
      primary_key: ["id"],
      table: ["chat", "message"],
      type: :primary_key,
    }
    assert {:ok, expected} == AlterTable.parse("""
    ALTER TABLE ONLY chat.message
        ADD CONSTRAINT message_pkey PRIMARY KEY (id);
    """)

    expected = %{
      action: :add_table_constraint,
      constraint_name: "message_upload_pkey",
      primary_key: ["uuid"],
      table: ["chat", "message_upload"],
      type: :primary_key,
    }
    assert {:ok, expected} == AlterTable.parse("""
    ALTER TABLE ONLY chat.message_upload
        ADD CONSTRAINT message_upload_pkey PRIMARY KEY (uuid);
    """)

    expected = %{
      action: :add_table_constraint,
      constraint_name: "pending_chunk_pkey",
      primary_key: ["uuid", "chunk"],
      table: ["chat", "pending_chunk"],
      type: :primary_key,
    }
    assert {:ok, expected} == AlterTable.parse("""
    ALTER TABLE ONLY chat.pending_chunk
        ADD CONSTRAINT pending_chunk_pkey PRIMARY KEY (uuid, chunk);
    """)
  end

  test "unique" do
    expected = %{
      action: :add_table_constraint,
      constraint_name: "session_token_key",
      table: ["chat", "session"],
      columns: ["token"],
      type: :unique,
    }
    assert {:ok, expected} == AlterTable.parse("""
    ALTER TABLE ONLY chat.session
        ADD CONSTRAINT session_token_key UNIQUE (token);
    """)

    expected = %{
      action: :add_table_constraint,
      constraint_name: "access_case_facility_case_id_key",
      table: ["public", "access_case_facility"],
      type: :unique,
      columns: ["case_id", "facility_id"]
    }
    assert {:ok, expected} == AlterTable.parse("""
    ALTER TABLE ONLY public.access_case_facility
        ADD CONSTRAINT access_case_facility_case_id_key UNIQUE (case_id, facility_id);
    """)
  end

  test "column constraint" do
    expected = %{
      action: :set_default,
      table: ["chat", "assignment"],
      column: "id",
      default: {:fragment, "nextval('chat.assignment_id_seq'::regclass)"}
    }
    assert {:ok, expected} == AlterTable.parse("""
    ALTER TABLE ONLY chat.assignment
        ALTER COLUMN id SET DEFAULT nextval('chat.assignment_id_seq'::regclass);
    """)
  end

  test "foreign key" do
    expected = %{
      action: :add_table_constraint,
      columns: ["user_id"],
      table: ["chat", "assignment"],
      constraint_name: "assignment_care_taker_id_fkey",
      references_columns: ["id"],
      references_table: ["chat", "user"],
      type: :foreign_key,
    }
    assert {:ok, expected} == AlterTable.parse("""
    ALTER TABLE ONLY chat.assignment
        ADD CONSTRAINT assignment_care_taker_id_fkey FOREIGN KEY (user_id) REFERENCES chat."user"(id);
    """)

    expected = %{
      action: :add_table_constraint,
      columns: ["facility_id"],
      constraint_name: "access_case_facility_facility_id_fkey",
      references_columns: ["id"],
      references_table: ["public", "facility"],
      table: ["public", "access_case_facility"],
      on_delete: :cascade,
      type: :foreign_key
    }
    assert {:ok, expected} == AlterTable.parse("""
    ALTER TABLE ONLY public.access_case_facility
        ADD CONSTRAINT access_case_facility_facility_id_fkey FOREIGN KEY (facility_id) REFERENCES public.facility(id) ON DELETE CASCADE;
    """)

    expected = %{
      action: :add_table_constraint,
      columns: ["cache_table_id"],
      constraint_name: "cache_table_row_cache_table_id_fkey",
      references_columns: ["id"],
      references_table: ["public", "cache_table"],
      table: ["public", "cache_table_row"],
      on_update: :cascade,
      on_delete: :cascade,
      type: :foreign_key,
    }
    assert {:ok, expected} == AlterTable.parse("""
    ALTER TABLE ONLY public.cache_table_row
        ADD CONSTRAINT cache_table_row_cache_table_id_fkey FOREIGN KEY (cache_table_id) REFERENCES public.cache_table(id) ON UPDATE CASCADE ON DELETE CASCADE;
    """)

    expected = %{
      action: :add_table_constraint,
      columns: ["creator_id"],
      constraint_name: "report_query_creator_id_fkey",
      references_columns: ["id"],
      references_table: ["public", "click_user"],
      table: ["public", "report_query"],
      on_delete: :set_null,
      type: :foreign_key,
    }
    assert {:ok, expected} == AlterTable.parse("""
    ALTER TABLE ONLY public.report_query
        ADD CONSTRAINT report_query_creator_id_fkey FOREIGN KEY (creator_id) REFERENCES public.click_user(id) ON DELETE SET NULL;
    """)
  end

  def value({:ok, value, "", _, _, _}), do: value
  def value({:error, value, _, _, _, _}), do: value
end
