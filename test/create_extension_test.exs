defmodule CreateExtensionTest do
  use ExUnit.Case

  alias EctoExtractMigrations.Parsers.CreateExtension

  test "parse" do
    input = "CREATE EXTENSION IF NOT EXISTS pg_stat_statements WITH SCHEMA public;"
    assert {:ok, %{name: "pg_stat_statements", schema: "public"}} == CreateExtension.parse(input)
  end

end
