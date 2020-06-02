defmodule CreateTypeTest do
  use ExUnit.Case

  alias EctoExtractMigrations.Parsers.CreateType

  test "create type" do
    expected = %{
      labels: ["paid", "unpaid", "partial"],
      name: ["public", "case_payment_status"]
    }
    assert {:ok, expected} == CreateType.parse("""
    CREATE TYPE public.case_payment_status AS ENUM (
        'paid',
        'unpaid',
        'partial'
    );
    """)
  end
end
