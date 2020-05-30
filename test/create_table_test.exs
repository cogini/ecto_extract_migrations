defmodule CreateTableTest do
  use ExUnit.Case

  alias EctoExtractMigrations.CreateTable

  test "parse_table_name" do
    assert {:ok, [{:name, "foo"}]} == CreateTable.parse_table_name("foo")
    assert {:ok, [{:name, "foo"}]} == CreateTable.parse_table_name("\"foo\"")
    assert {:ok, [{:name, "foo"}]} == CreateTable.parse_table_name("\"foo\"")
    assert {:ok, [{:name, ["public", "foo"]}]} == CreateTable.parse_table_name("public.foo")
    assert {:ok, [{:name, ["public", "foo"]}]} == CreateTable.parse_table_name("public.\"foo\"")
  end

  test "parse_create_table" do
    assert {:ok, %{columns: [], name: "device"}} == CreateTable.parse("CREATE TABLE device ();")
    assert {:ok, %{columns: [], name: ["public", "data_table_974"]}} == CreateTable.parse("CREATE TABLE public.data_table_974 ();")
    assert {:ok, %{columns: [], name: ["public", "data_table__tamil__form"]}} == CreateTable.parse("CREATE TABLE public.data_table__tamil__form ();")
    assert {:ok, %{columns: [], name: ["public", "device"]}} == CreateTable.parse("CREATE TABLE public.device ();")
  end

  test "parse_session" do
    sql = """
    CREATE TABLE session (
      uid BYTEA NOT NULL PRIMARY KEY,
      isPersistent BOOLEAN NOT NULL DEFAULT FALSE,
      touched INTEGER
    );
    """
    #  avatar_id INTEGER REFERENCES warp_avatar(id) ON DELETE CASCADE);
    # assert ["device"] == value(CreateTable.parse(sql))
    expected = %{
      name: "session",
      columns: [
        %{name: "uid", null: false, primary_key: true, type: :bytea},
        %{default: false, name: "isPersistent", null: false, type: :boolean},
        %{name: "touched", type: :integer}
      ]
    }
    assert {:ok, expected} == CreateTable.parse(sql)
  end

  # test "parse_varchar" do
  #   sql = """
  #   CREATE TABLE bnd.t_eligibility (
  #       rowid integer,
  #       member_id character varying(50) NOT NULL,
  #       mbi character varying(50),
  #       dob timestamp without time zone,
  #       age integer,
  #   );
  #   """
  #   #  avatar_id INTEGER REFERENCES warp_avatar(id) ON DELETE CASCADE);
  #   # assert ["device"] == value(CreateTable.parse(sql))
  #   expected = %{
  #     name: "session",
  #     columns: [
  #       %{name: "uid", null: false, primary_key: true, type: "BYTEA"},
  #       %{default: false, name: "isPersistent", null: false, type: "BOOLEAN"},
  #       %{name: "touched", type: "INTEGER"}
  #     ]
  #   }
  #   assert {:ok, expected} == CreateTable.parse(sql)
  # end

  test "column" do
    assert [%{name: "uid", null: false, primary_key: true, type: :bytea}] == value(CreateTable.parse_column("uid BYTEA NOT NULL PRIMARY KEY,"))
    assert [%{default: false, name: "isPersistent", null: false, type: :boolean}] == value(CreateTable.parse_column("isPersistent BOOLEAN NOT NULL DEFAULT FALSE,"))
    assert [%{default: 0, name: "size", null: false, type: :integer}] == value(CreateTable.parse_column("size INTEGER NOT NULL DEFAULT 0,"))
    assert [%{}] == value(CreateTable.parse_column("member_id character varying(50) NOT NULL"))
    assert [%{}] == value(CreateTable.parse_column("mbi character varying(50)"))
  end

  def value({:ok, value, _, _, _, _}), do: value
  def value({:error, value, _, _, _, _}), do: value
end
