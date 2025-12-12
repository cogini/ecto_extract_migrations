defmodule CreateTableTest do
  use ExUnit.Case

  alias EctoExtractMigrations.Parsers.CreateTable

  test "match" do
    assert {:ok, %{columns: [], name: "device"}} == CreateTable.match("CREATE TABLE device ();")
    assert {:continue, %{sql: "CREATE TABLE device"}} = CreateTable.match("CREATE TABLE device")
  end

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
    expected = [%{name: "admit_risk", precision: 18, scale: 2, type: :numeric}]
    assert {:ok, expected} == CreateTable.parse_column(input)

    input = "admit_risk numeric(18)"
    expected = [%{name: "admit_risk", precision: 18, type: :numeric}]
    assert {:ok, expected} == CreateTable.parse_column(input)

    input = "admit_risk numeric"
    expected = [%{name: "admit_risk", type: :numeric}]
    assert {:ok, expected} == CreateTable.parse_column(input)

    input = "avatar_id INTEGER REFERENCES warp_avatar(id) ON DELETE CASCADE"
    expected = [%{name: "avatar_id", type: :integer, on_delete: :cascade, references_column: ["id"], references_table: "warp_avatar"}]
    assert {:ok, expected} == CreateTable.parse_column(input)

    input = """
    customization_options text DEFAULT '{"logo": "", "email_body": "<p>Dear %(title)s %(surname)s:</p>\n\n<p>\n  Your case %(shortname)s for patient %(patient_id)s has been submitted.<br /> \n  You can view your case at <a href=\"%(case_url)s\">%(case_url)s</a>.\n</p>", "use_default_config": "false"}'::text NOT NULL",
    """
    expected = [%{default: "{\"logo\": \"\", \"email_body\": \"<p>Dear %(title)s %(surname)s:</p>\n\n<p>\n  Your case %(shortname)s for patient %(patient_id)s has been submitted.<br /> \n  You can view your case at <a href=\"%(case_url)s\">%(case_url)s</a>.\n</p>\", \"use_default_config\": \"false\"}", name: "customization_options", null: false, type: :text}]
    assert {:ok, expected} == CreateTable.parse_column(input)
  end

  test "table constraint check" do
    expected = [{:type, :constraint}, {:name, "case_coupon_current_uses_check"}, {:check, "(current_uses >= 0)"}]
    input = "CONSTRAINT case_coupon_current_uses_check CHECK ((current_uses >= 0))"
    assert {:ok, expected} == CreateTable.parse_table_constraint(input)

    expected = [{:type, :constraint}, {:name, "case_coupon_discount_percentage_check"}, {:check, "(discount_percentage >= 0)"}]
    input = "CONSTRAINT case_coupon_discount_percentage_check CHECK ((discount_percentage >= 0))"
    assert {:ok, expected} == CreateTable.parse_table_constraint(input)

    expected = [{:type, :constraint}, {:name, "case_coupon_max_uses_check"}, {:check, "(max_uses >= 0)"}]
    input = "CONSTRAINT case_coupon_max_uses_check CHECK ((max_uses >= 0))"
    assert {:ok, expected} == CreateTable.parse_table_constraint(input)

    expected = [{:type, :constraint}, {:name, "attempt_range"}, {:check, "((attempt >= 0) AND (attempt <= max_attempts))"}]
    input = "CONSTRAINT attempt_range CHECK (((attempt >= 0) AND (attempt <= max_attempts)))"
    assert {:ok, expected} == CreateTable.parse_table_constraint(input)

    expected = [{:type, :constraint}, {:name, "queue_length"}, {:check, "((char_length(queue) > 0) AND (char_length(queue) < 128))"}]
    input = "CONSTRAINT queue_length CHECK (((char_length(queue) > 0) AND (char_length(queue) < 128)))"
    assert {:ok, expected} == CreateTable.parse_table_constraint(input)
  end

  test "parse_session" do
    sql = """
    CREATE TABLE session (
      uid BYTEA NOT NULL PRIMARY KEY,
      isPersistent BOOLEAN NOT NULL DEFAULT FALSE,
      touched INTEGER,
      avatar_id INTEGER REFERENCES warp_avatar(id) ON DELETE CASCADE
    );
    """
    expected = %{
      name: "session",
      columns: [
        %{name: "uid", null: false, primary_key: true, type: :bytea},
        %{default: false, name: "isPersistent", null: false, type: :boolean},
        %{name: "touched", type: :integer},
        %{name: "avatar_id", on_delete: :cascade, references_column: ["id"], references_table: "warp_avatar", type: :integer},
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

  test "create table with id sequence" do
    sql = """
    CREATE TABLE public.activities (
        id integer DEFAULT nextval('public.activities_id_seq'::regclass) NOT NULL,
        course_id integer,
        task_category_id integer,
        next_action_handled_by integer,
        status character varying(255) DEFAULT 'Not Done'::character varying,
        due_on date,
        completed_on date,
        memo text,
        created_at timestamp without time zone,
        updated_at timestamp without time zone,
        next_action character varying(255),
        completed boolean DEFAULT false,
        company_id integer,
        created_by_id integer,
        next_action_on date,
        subject character varying(255),
        owned_by integer,
        updated_by_id integer
    );

    """
    expected = %{
      columns: [
        %{name: "id", null: false, type: :integer, default: "nextval('public.activities_id_seq'::regclass)"},
        %{name: "course_id", type: :integer},
        %{name: "task_category_id", type: :integer},
        %{name: "next_action_handled_by", type: :integer},
        %{name: "status", type: :"character varying", default: "Not Done", size: 255},
        %{name: "due_on", type: :date},
        %{name: "completed_on", type: :date},
        %{name: "memo", type: :text},
        %{name: "created_at", type: :"timestamp without time zone"},
        %{name: "updated_at", type: :"timestamp without time zone"},
        %{name: "next_action", size: 255, type: :"character varying"},
        %{default: false, name: "completed", type: :boolean},
        %{name: "company_id", type: :integer},
        %{name: "created_by_id", type: :integer},
        %{name: "next_action_on", type: :date},
        %{name: "subject", size: 255, type: :"character varying"},
        %{name: "owned_by", type: :integer},
        %{name: "updated_by_id", type: :integer}
      ],
      name: ["public", "activities"]
    }
    assert {:ok, expected} == CreateTable.parse(sql)
  end

  test "create table with timestamp" do
    sql = """
    CREATE TABLE public.assignment_logs (
        id bigint NOT NULL,
        assignment_id bigint,
        user_id bigint,
        inserted_at timestamp(0) without time zone NOT NULL,
        updated_at timestamp(0) without time zone NOT NULL,
        authorized boolean
    );
    """
    expected = %{
      columns: [
         %{name: "id", null: false, type: :bigint},
         %{name: "assignment_id", type: :bigint},
         %{name: "user_id", type: :bigint},
         %{name: "inserted_at", type: :timestamp, null: false, precision: 0, tz: false},
         %{name: "updated_at", type: :timestamp, null: false, precision: 0, tz: false},
         %{name: "authorized", type: :boolean}
      ],
      name: ["public", "assignment_logs"]
    }
    assert {:ok, expected} == CreateTable.parse(sql)
  end

  test "create table bpchar" do
    sql = """
    CREATE TABLE public.client (
        client_code character varying(20) NOT NULL,
        e_name character varying(250),
        c_name character varying(250),
        business_id character(8),
        invoice_title character varying(100),
        group_id integer DEFAULT 0 NOT NULL,
        charge_sales_tax character(3) DEFAULT 'Yes'::bpchar,
        phone character varying(50),
        fax character varying(50),
        contact_email character varying(50),
        postal_code character(3),
        address character varying(250),
        url character varying(150),
        industry character varying(200),
        number_employee integer DEFAULT 0,
        transportation_fee integer DEFAULT 0,
        status character varying(20) DEFAULT 'Active'::character varying NOT NULL,
        memo text,
        admin character varying(20) DEFAULT 'foo'::character varying NOT NULL,
        eng_address character varying(250),
        contact_cname character varying(120),
        contact_ename character varying(120),
        contact_direct_line character varying(50),
        contact_extension character varying(50),
        contact_mobile character varying(25),
        password character varying(30),
        company_id integer
    );
    """
    expected = %{
      columns: [
        %{name: "client_code", null: false, type: :"character varying", size: 20},
        %{name: "e_name", type: :"character varying", size: 250},
        %{name: "c_name", type: :"character varying", size: 250},
        %{name: "business_id", type: :character, size: 8},
        %{name: "invoice_title", type: :"character varying", size: 100},
        %{name: "group_id", type: :integer, default: 0, null: false},
        %{default: "Yes", name: "charge_sales_tax", size: 3, type: :character},
        %{name: "phone", size: 50, type: :"character varying"},
        %{name: "fax", size: 50, type: :"character varying"},
        %{name: "contact_email", size: 50, type: :"character varying"},
        %{name: "postal_code", size: 3, type: :character},
        %{name: "address", size: 250, type: :"character varying"},
        %{name: "url", size: 150, type: :"character varying"},
        %{name: "industry", size: 200, type: :"character varying"},
        %{default: 0, name: "number_employee", type: :integer},
        %{default: 0, name: "transportation_fee", type: :integer},
        %{default: "Active", name: "status", size: 20, type: :"character varying", null: false},
        %{name: "memo", type: :text},
        %{default: "foo", name: "admin", size: 20, type: :"character varying", null: false},
        %{name: "eng_address", size: 250, type: :"character varying"},
        %{name: "contact_cname", size: 120, type: :"character varying"},
        %{name: "contact_ename", size: 120, type: :"character varying"},
        %{name: "contact_direct_line", size: 50, type: :"character varying"},
        %{name: "contact_extension", size: 50, type: :"character varying"},
        %{name: "contact_mobile", size: 25, type: :"character varying"},
        %{name: "password", size: 30, type: :"character varying"},
        %{name: "company_id", type: :integer}
       ],
       name: ["public", "client"]
    }
    assert {:ok, expected} == CreateTable.parse(sql)
  end

  test "create table timestamp without time zone DEFAULT now()" do
    sql = """
    CREATE TABLE public.descriptor_references (
        id integer NOT NULL,
        descriptor_reference_category_id integer,
        content character varying(255),
        "position" integer DEFAULT 10,
        active boolean DEFAULT true,
        created_at timestamp without time zone DEFAULT now() NOT NULL,
        updated_at timestamp without time zone DEFAULT now() NOT NULL
    );
    """
    expected = %{
      columns: [
         %{name: "id", null: false, type: :integer},
         %{name: "descriptor_reference_category_id", type: :integer},
         %{name: "content", size: 255, type: :"character varying"},
         %{name: "position", type: :integer, default: 10},
         %{name: "active", type: :boolean, default: true},
         %{default: {:fragment, "now()"}, name: "created_at", null: false, type: :timestamp, tz: false},
         %{default: {:fragment, "now()"}, name: "updated_at", type: :timestamp, null: false, tz: false}
      ],
      name: ["public", "descriptor_references"]
    }
    assert {:ok, expected} == CreateTable.parse(sql)
  end

  test "create table default custom enum" do
    sql = """
    CREATE TABLE public.oban_jobs (
        id bigint NOT NULL,
        state public.oban_job_state DEFAULT 'available'::public.oban_job_state NOT NULL,
        queue text DEFAULT 'default'::text NOT NULL,
        worker text NOT NULL,
        args jsonb DEFAULT '{}'::jsonb NOT NULL,
        errors jsonb[] DEFAULT ARRAY[]::jsonb[] NOT NULL,
        attempt integer DEFAULT 0 NOT NULL,
        max_attempts integer DEFAULT 20 NOT NULL,
        inserted_at timestamp without time zone DEFAULT timezone('UTC'::text, now()) NOT NULL,
        scheduled_at timestamp without time zone DEFAULT timezone('UTC'::text, now()) NOT NULL,
        attempted_at timestamp without time zone,
        completed_at timestamp without time zone,
        attempted_by text[],
        discarded_at timestamp without time zone,
        priority integer DEFAULT 0 NOT NULL,
        tags text[] DEFAULT ARRAY[]::text[],
        meta jsonb DEFAULT '{}'::jsonb,
        cancelled_at timestamp without time zone,
        CONSTRAINT attempt_range CHECK (((attempt >= 0) AND (attempt <= max_attempts))),
        CONSTRAINT positive_max_attempts CHECK ((max_attempts > 0)),
        CONSTRAINT queue_length CHECK (((char_length(queue) > 0) AND (char_length(queue) < 128))),
        CONSTRAINT worker_length CHECK (((char_length(worker) > 0) AND (char_length(worker) < 128)))
    );
    """
    expected = %{
      columns: [
        %{name: "id", null: false, type: :bigint},
        %{name: "state", type: ["public", "oban_job_state"], default: "available", null: false},
        %{name: "queue", type: :text, default: "default", null: false},
        %{name: "worker", type: :text, null: false},
        %{default: "{}", name: "args", type: :jsonb, null: false},
        %{default: "ARRAY[]::jsonb[]", name: "errors", null: false, type: :jsonb, is_array: true},
        %{default: 0, name: "attempt", null: false, type: :integer},
        %{default: 20, name: "max_attempts", type: :integer, null: false},
        %{default: {:fragment, "timezone('UTC'::text, now())"}, name: "inserted_at", type: :timestamp, null: false, tz: false},
        %{default: {:fragment, "timezone('UTC'::text, now())"}, name: "scheduled_at", type: :timestamp, null: false, tz: false},
        %{name: "attempted_at", type: :timestamp, tz: false},
        %{name: "completed_at", type: :timestamp, tz: false},
        %{name: "attempted_by", type: :text, is_array: true},
        %{name: "discarded_at", type: :timestamp, tz: false},
        %{default: 0, name: "priority", type: :integer, null: false},
        %{default: "ARRAY[]::text[],\n", name: "tags", type: :text, is_array: true},
        %{default: "{}", name: "meta", type: :jsonb},
        %{name: "cancelled_at", type: :timestamp, tz: false}
      ],
      name: ["public", "oban_jobs"],
      constraints: [
        %{name: "attempt_range", type: :constraint, check: "((attempt >= 0) AND (attempt <= max_attempts))"},
        %{name: "positive_max_attempts", type: :constraint, check: "(max_attempts > 0)"},
        %{name: "queue_length", type: :constraint, check: "((char_length(queue) > 0) AND (char_length(queue) < 128))"},
        %{name: "worker_length", type: :constraint, check: "((char_length(worker) > 0) AND (char_length(worker) < 128))"}
      ]
    }
    assert {:ok, expected} == CreateTable.parse(sql)
  end

  test "starts_with_number" do
    assert EctoExtractMigrations.Commands.CreateTable.starts_with_number("10")
    assert EctoExtractMigrations.Commands.CreateTable.starts_with_number("01")
    refute EctoExtractMigrations.Commands.CreateTable.starts_with_number("fish")
  end

  def value({:ok, [value], "", _, _, _}), do: value
  def value({:error, value, _, _, _, _}), do: value
end
