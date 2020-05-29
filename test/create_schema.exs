defmodule CreateSchemaTest do
  use ExUnit.Case

  alias EctoExtractMigrations.CreateSchema

  test "parse" do
    assert CreateSchema.parse("CREATE SCHEMA foo;") == {:ok, ["foo"], _, _, _}
    assert CreateSchema.parse("CREATE SCHEMA \"foo\";") == {:ok, ["foo"], _, _, _}
  end
end
