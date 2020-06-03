defmodule EctoExtractMigrationsTest do
  use ExUnit.Case

  import EctoExtractMigrations

  test "format_module_name/1" do
    assert "Mytable" == format_module_name("mytable")
    assert "Myschema.Mytable" == format_module_name(["myschema", "mytable"])
    assert "Mytable" == format_module_name(["public", "mytable"])
  end

end
