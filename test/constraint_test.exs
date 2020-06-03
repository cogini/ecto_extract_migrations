defmodule ConstraintTest do
  use ExUnit.Case

  alias EctoExtractMigrations.Constraint

  test "format_constraint" do
    expected = ~s|constraint("public.foo", :current_uses_check, check: "(current_uses >= 0)")|
    assert expected == Constraint.format_constraint(%{name: "current_uses_check", check: "(current_uses >= 0)"}, "public.foo")
  end

end
