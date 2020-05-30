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

  test "column" do
    assert [%{default: "email", name: "contact", size: 64, type: :"character varying", null: false}] == value(CreateTable.parse_column("contact character varying(64) DEFAULT 'email'::character varying NOT NULL"))
    assert [%{default: "", name: "name", null: false, size: 128, type: :"character varying"}] == value(CreateTable.parse_column("name character varying(128) DEFAULT ''::character varying NOT NULL"))
    assert [%{default: true, name: "is_active", null: false, type: :boolean}] == value(CreateTable.parse_column("is_active boolean DEFAULT true NOT NULL"))
    assert [%{default: false, name: "is_student", null: false, type: :boolean}] == value(CreateTable.parse_column("is_student boolean DEFAULT false NOT NULL"))
    assert [%{name: "PRIM CHRONIC COND", type: :"character varying", size: 50}] == value(CreateTable.parse_column(~s|"PRIM CHRONIC COND" character varying(50)|))
    assert [%{name: "uid", null: false, primary_key: true, type: :bytea}] == value(CreateTable.parse_column("uid BYTEA NOT NULL PRIMARY KEY,"))
    assert [%{name: "isPersistent", null: false, type: :boolean, default: false}] == value(CreateTable.parse_column("isPersistent BOOLEAN NOT NULL DEFAULT FALSE"))
    assert [%{default: 0, name: "size", null: false, type: :integer}] == value(CreateTable.parse_column("size INTEGER NOT NULL DEFAULT 0,"))
    assert [%{name: "member_id", null: false, size: 50, type: :"character varying"}] == value(CreateTable.parse_column("member_id character varying(50) NOT NULL"))
    assert [%{name: "mbi", size: 50, type: :"character varying"}] == value(CreateTable.parse_column("mbi character varying(50)"))
    assert [%{name: "admit_risk", size: [18, 2], type: :numeric}] == value(CreateTable.parse_column("admit_risk numeric(18,2)"))
  end

  test "table_constraint" do
    assert [name: "case_coupon_current_uses_check", check: "((current_uses >= 0))"] == value(CreateTable.parsec_table_constraint("CONSTRAINT case_coupon_current_uses_check CHECK ((current_uses >= 0))"))
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

  test "parse_varchar" do
    sql = """
    CREATE TABLE bnd.t_eligibility (
        rowid integer,
        member_id character varying(50) NOT NULL,
        mbi character varying(50),
        dob timestamp without time zone,
        age integer,
    );
    """
    expected = %{
      name: ["bnd", "t_eligibility"],
      columns: [
        %{name: "rowid", type: :integer},
        %{name: "member_id", type: :"character varying", size: 50, null: false},
        %{name: "mbi", type: :"character varying", size: 50},
        %{name: "dob", type: :"timestamp without time zone"},
        %{name: "age", type: :integer},
      ]
    }
    assert {:ok, expected} == CreateTable.parse(sql)
  end

  def value({:ok, value, "", _, _, _}), do: value
  def value({:error, value, _, _, _, _}), do: value
end
