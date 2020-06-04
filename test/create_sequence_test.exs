defmodule CreateSequenceTest do
  use ExUnit.Case

  alias EctoExtractMigrations.Parsers.CreateSequence

  test "create_sequence" do
    sql = """
    CREATE SEQUENCE chat.assignment_id_seq
        START WITH 1
        INCREMENT BY 1
        NO MINVALUE
        NO MAXVALUE
        CACHE 1;
    """
    expected = %{
      name: ["chat", "assignment_id_seq"],
      cache: 1,
      increment: 1,
      maxvalue: false,
      minvalue: false,
      start: 1,
    }
    assert {:ok, expected} == CreateSequence.parse(sql)
  end

end

