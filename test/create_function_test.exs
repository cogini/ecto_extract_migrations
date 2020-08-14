defmodule CreateFunctionTest do
  use ExUnit.Case

  alias EctoExtractMigrations.Parsers.CreateFunction

  describe "parse" do
    test "create function" do
      expected = %{name: ["public", "cast_to_decimal"], delimiter: "$_$"}
      assert {:ok, expected} == CreateFunction.parse("""
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
      """)

      expected = %{name: ["public", "ensure_access_case_facility"], delimiter: "$$"}
      assert {:ok, expected} == CreateFunction.parse("""
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
      """)
    end

  end
end
