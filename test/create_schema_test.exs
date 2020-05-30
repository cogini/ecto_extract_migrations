defmodule CreateSchemaTest do
  use ExUnit.Case

  alias EctoExtractMigrations.CreateSchema

  test "parse" do
    assert [{:name, "foo"}] == value(CreateSchema.parse("CREATE SCHEMA foo;"))
    assert [{:name, "foo"}] == value(CreateSchema.parse("CREATE SCHEMA \"foo\";"))
  end

  def value({:ok, value, _, _, _, _}), do: value
end
