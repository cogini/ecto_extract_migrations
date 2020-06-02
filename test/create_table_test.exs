defmodule CreateTableTest do
  use ExUnit.Case

  alias EctoExtractMigrations.Parsers.CreateTable

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
    expected = [{:type, :constraint}, {:name, "case_coupon_current_uses_check"}, {:check, "((current_uses >= 0))"}]
    assert expected == value(CreateTable.parsec_table_constraint("CONSTRAINT case_coupon_current_uses_check CHECK ((current_uses >= 0))"))

    expected = [{:type, :constraint}, {:name, "case_coupon_discount_percentage_check"}, {:check, "((discount_percentage >= 0))"}]
    assert expected == value(CreateTable.parsec_table_constraint("CONSTRAINT case_coupon_discount_percentage_check CHECK ((discount_percentage >= 0))"))

    expected = [{:type, :constraint}, {:name, "case_coupon_max_uses_check"}, {:check, "((max_uses >= 0))"}]
    assert expected == value(CreateTable.parsec_table_constraint("CONSTRAINT case_coupon_max_uses_check CHECK ((max_uses >= 0))"))
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

  test "create table with constraints" do
    sql = """
    CREATE TABLE public.case_coupon (
        id integer NOT NULL,
        facility_id integer NOT NULL,
        code character varying(64) NOT NULL,
        discount_percentage integer NOT NULL,
        discount_amount integer NOT NULL,
        max_uses integer NOT NULL,
        current_uses integer NOT NULL,
        start_date timestamp without time zone,
        end_date timestamp without time zone,
        CONSTRAINT case_coupon_current_uses_check CHECK ((current_uses >= 0)),
        CONSTRAINT case_coupon_discount_percentage_check CHECK ((discount_percentage >= 0)),
        CONSTRAINT case_coupon_discount_percentage_check1 CHECK ((discount_percentage >= 0)),
        CONSTRAINT case_coupon_max_uses_check CHECK ((max_uses >= 0))
    );
    """
    expected = %{
      columns: [
        %{name: "id", type: :integer, null: false},
        %{name: "facility_id", null: false, type: :integer},
        %{name: "code", size: 64, type: :"character varying", null: false},
        %{name: "discount_percentage", type: :integer, null: false},
        %{name: "discount_amount", type: :integer, null: false},
        %{name: "max_uses", null: false, type: :integer},
        %{name: "current_uses", null: false, type: :integer},
        %{name: "start_date", type: :"timestamp without time zone"},
        %{name: "end_date", type: :"timestamp without time zone"}
      ],
      name: ["public", "case_coupon"],
      constraints: [
        %{check: "(current_uses >= 0)", name: "case_coupon_current_uses_check", type: :constraint},
        %{check: "(discount_percentage >= 0)", name: "case_coupon_discount_percentage_check", type: :constraint},
        %{check: "(discount_percentage >= 0)", name: "case_coupon_discount_percentage_check1", type: :constraint},
        %{check: "(max_uses >= 0)", name: "case_coupon_max_uses_check", type: :constraint}
      ]
    }
    assert {:ok, expected} == CreateTable.parse(sql)
  end

  test "starts_with_number" do
    assert EctoExtractMigrations.Table.starts_with_number("10")
    assert EctoExtractMigrations.Table.starts_with_number("01")
    refute EctoExtractMigrations.Table.starts_with_number("fish")
  end

  def value({:ok, value, "", _, _, _}), do: value
  def value({:error, value, _, _, _, _}), do: value
end
