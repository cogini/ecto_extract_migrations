defmodule EctoExtractMigrationsTest do
  use ExUnit.Case

  import EctoExtractMigrations

  test "format_table_name/1" do
    assert "mytable" == format_table_name("mytable")
    assert "myschema.mytable" == format_table_name(["myschema", "mytable"])
    assert "mytable" == format_table_name(["public", "mytable"])
  end

end
