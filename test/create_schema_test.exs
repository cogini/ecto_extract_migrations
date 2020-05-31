defmodule CreateSchemaTest do
  use ExUnit.Case

  alias EctoExtractMigrations.CreateSchema

  test "parse" do
    assert {:ok, [{:name, "foo"}]} == CreateSchema.parse("CREATE SCHEMA foo;")
    assert {:ok, [{:name, "foo"}]} == CreateSchema.parse("CREATE SCHEMA \"foo\";")
  end
end
