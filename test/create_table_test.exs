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
    input = "contact character varying(64) DEFAULT 'email'::character varying NOT NULL"
    expected = [%{default: "email", name: "contact", size: 64, type: :"character varying", null: false}]
    assert {:ok, expected} == CreateTable.parse_column(input)

    input = "name character varying(128) DEFAULT ''::character varying NOT NULL"
    expected = [%{default: "", name: "name", null: false, size: 128, type: :"character varying"}]
    assert {:ok, expected} == CreateTable.parse_column(input)

    input = "is_active boolean DEFAULT true NOT NULL"
    expected = [%{default: true, name: "is_active", null: false, type: :boolean}]
    assert {:ok, expected} == CreateTable.parse_column(input)

    input = "is_student boolean DEFAULT false NOT NULL"
    expected = [%{default: false, name: "is_student", null: false, type: :boolean}]
    assert {:ok, expected} == CreateTable.parse_column(input)

    input = ~s|"PRIM CHRONIC COND" character varying(50)|
    expected = [%{name: "PRIM CHRONIC COND", type: :"character varying", size: 50}]
    assert {:ok, expected} == CreateTable.parse_column(input)

    expected = [%{name: "uid", null: false, primary_key: true, type: :bytea}]
    input = "uid BYTEA NOT NULL PRIMARY KEY,"
    assert {:ok, expected} == CreateTable.parse_column(input)

    input = "isPersistent BOOLEAN NOT NULL DEFAULT FALSE"
    expected = [%{name: "isPersistent", null: false, type: :boolean, default: false}]
    assert {:ok, expected} == CreateTable.parse_column(input)

    input = "size INTEGER NOT NULL DEFAULT 0,"
    expected = [%{default: 0, name: "size", null: false, type: :integer}]
    assert {:ok, expected} == CreateTable.parse_column(input)

    input = "member_id character varying(50) NOT NULL"
    expected = [%{name: "member_id", null: false, size: 50, type: :"character varying"}]
    assert {:ok, expected} == CreateTable.parse_column(input)

    input = "mbi character varying(50)"
    expected = [%{name: "mbi", size: 50, type: :"character varying"}]
    assert {:ok, expected} == CreateTable.parse_column(input)

    input = "admit_risk numeric(18,2)"
    expected = [%{name: "admit_risk", size: [18, 2], type: :numeric}]
    assert {:ok, expected} == CreateTable.parse_column(input)

    input = """
    customization_options text DEFAULT '{"logo": "", "email_body": "<p>Dear %(title)s %(surname)s:</p>\n\n<p>\n  Your case %(shortname)s for patient %(patient_id)s has been submitted.<br /> \n  You can view your case at <a href=\"%(case_url)s\">%(case_url)s</a>.\n</p>", "use_default_config": "false"}'::text NOT NULL",
    """
    expected = [%{default: "{\"logo\": \"\", \"email_body\": \"<p>Dear %(title)s %(surname)s:</p>\n\n<p>\n  Your case %(shortname)s for patient %(patient_id)s has been submitted.<br /> \n  You can view your case at <a href=\"%(case_url)s\">%(case_url)s</a>.\n</p>\", \"use_default_config\": \"false\"}", name: "customization_options", null: false, type: :text}]
    assert {:ok, expected} == CreateTable.parse_column(input)
  end

  test "table_constraint" do
    expected = [{:type, :constraint}, {:name, "case_coupon_current_uses_check"}, {:check, "((current_uses >= 0))"}]
    assert {:ok, expected} == CreateTable.parse_table_constraint("CONSTRAINT case_coupon_current_uses_check CHECK ((current_uses >= 0))")

    expected = [{:type, :constraint}, {:name, "case_coupon_discount_percentage_check"}, {:check, "((discount_percentage >= 0))"}]
    assert {:ok, expected} == CreateTable.parse_table_constraint("CONSTRAINT case_coupon_discount_percentage_check CHECK ((discount_percentage >= 0))")

    expected = [{:type, :constraint}, {:name, "case_coupon_max_uses_check"}, {:check, "((max_uses >= 0))"}]
    assert {:ok, expected} == CreateTable.parse_table_constraint("CONSTRAINT case_coupon_max_uses_check CHECK ((max_uses >= 0))")
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

  def value({:ok, [value], "", _, _, _}), do: value
  def value({:error, value, _, _, _, _}), do: value
end
