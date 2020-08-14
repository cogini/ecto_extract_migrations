defmodule EctoExtractMigrationsTest do
  use ExUnit.Case

  import EctoExtractMigrations

  test "sql_name_to_module/1" do
    assert "Mytable" == sql_name_to_module("mytable")
    assert "Myschema.Mytable" == sql_name_to_module(["myschema", "mytable"])
    assert "Mytable" == sql_name_to_module(["public", "mytable"])
  end

  describe "parse" do
    data = """
    --
    -- Name: cast_to_decimal(text, numeric); Type: FUNCTION; Schema: public; Owner: -
    --

    CREATE FUNCTION public.cast_to_decimal(text, numeric) RETURNS numeric
        LANGUAGE plpgsql IMMUTABLE
        AS $_$
    begin
        return cast($1 as decimal);
    exception
        when invalid_text_representation then
            return $2;
    end;
    $_$;


    --
    -- Name: chat_update_timestamp(); Type: FUNCTION; Schema: public; Owner: -
    --

    CREATE FUNCTION public.chat_update_timestamp() RETURNS trigger
        LANGUAGE plpgsql
        AS $$
    BEGIN
        NEW.updated_at = NOW() AT TIME ZONE 'UTC';
        RETURN NEW;
    END;
    $$;


    --
    -- Name: create_warp_session(); Type: FUNCTION; Schema: public; Owner: -
    --

    CREATE FUNCTION public.create_warp_session() RETURNS void
        LANGUAGE plpgsql
        AS $$
    BEGIN

    IF EXISTS (
      SELECT *
      FROM     pg_catalog.pg_tables
      WHERE    tablename  = 'warp_session'
      ) THEN
      RAISE NOTICE 'Table "warp_session" already exists.';
    ELSE
      CREATE TABLE warp_session (
        uid BYTEA NOT NULL PRIMARY KEY,
        isPersistent BOOLEAN NOT NULL DEFAULT FALSE,
        touched INTEGER,
        avatar_id INTEGER REFERENCES warp_avatar(id) ON DELETE CASCADE);
    END IF;

    END;
    $$;


    --
    -- Name: ensure_access_case_facility(integer, integer); Type: FUNCTION; Schema: public; Owner: -
    --

    CREATE FUNCTION public.ensure_access_case_facility(arg_case_id integer, arg_facility_id integer) RETURNS void
        LANGUAGE plpgsql
        AS $$
    DECLARE
    BEGIN
      INSERT INTO access_case_facility (case_id, facility_id)
        SELECT arg_case_id, arg_facility_id
        WHERE NOT EXISTS (
          SELECT 1 FROM access_case_facility
          WHERE case_id = arg_case_id
          AND facility_id = arg_facility_id);
    END;
    $$;


    --
    -- Name: ensure_access_case_user(integer, integer, bytea); Type: FUNCTION; Schema: public; Owner: -
    --

    CREATE FUNCTION public.ensure_access_case_user(arg_case_id integer, arg_user_id integer, arg_role_name bytea) RETURNS void
        LANGUAGE plpgsql
        AS $$
    DECLARE
    BEGIN
      INSERT INTO access_case_user (case_id, user_id, role_name)
        SELECT arg_case_id, arg_user_id, arg_role_name
        WHERE NOT EXISTS (
          SELECT 1 FROM access_case_user
          WHERE case_id = arg_case_id
          AND user_id = arg_user_id);
    END;
    $$;
    """

    results =
      data
      |> String.split("\n")
      |> Enum.map(&(&1 <> "\n"))
      |> Stream.with_index()
      |> Stream.transform(nil, &EctoExtractMigrations.parse/2)
      |> Stream.reject(&(&1.type in [:whitespace, :comment]))
      |> Enum.to_list()
      |> Enum.map(&(&1.data.name))
    expected = [
      ["public", "cast_to_decimal"],
      ["public", "chat_update_timestamp"],
      ["public", "create_warp_session"],
      ["public", "ensure_access_case_facility"],
      ["public", "ensure_access_case_user"]
    ]
    assert results == expected
  end

end
