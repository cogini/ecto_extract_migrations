defmodule AlterSequenceTest do
  use ExUnit.Case

  alias EctoExtractMigrations.Parsers.AlterSequence

  test "parse" do
    expected = %{
      owned_by: [table: ["public", "app_version"], column: "id"], sequence: ["public", "app_version_id_seq"]
    }
    assert {:ok, expected} == AlterSequence.parse("""
      ALTER SEQUENCE public.app_version_id_seq OWNED BY public.app_version.id;
    """)
  end

  describe "match/1" do
    test "one line" do
      expected = %{
        owned_by: [table: ["public", "data_table_2593"], column: "rowid"], sequence: ["public", "data_table_2593_rowid_seq"]
      }
      assert {:ok, expected} == AlterSequence.match("""
      ALTER SEQUENCE public.data_table_2593_rowid_seq OWNED BY public.data_table_2593.rowid;
      """)
    end
    test "multiline" do
      expected = %{
        owned_by: [table: ["public", "data_table_2593"], column: "rowid"], sequence: ["public", "data_table_2593_rowid_seq"]
      }
      assert {:ok, expected} == AlterSequence.match("""
      ALTER SEQUENCE public.data_table_2593_rowid_seq
      OWNED BY public.data_table_2593.rowid;
      """)
    end
  end
end
