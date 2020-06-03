defmodule TableTest do
  use ExUnit.Case

  alias EctoExtractMigrations.Table

  test "has_pk" do
    columns = [
      %{name: "id", null: false, primary_key: true, type: :integer},
      %{name: "questionnaire_id", null: false, type: :integer},
      %{name: "response_id", null: false, type: :integer}
    ]
    assert Table.has_pk(columns)
  end

  test "format_column" do
    assert "      add :uid, :bytea, primary_key: true, null: false\n" == Table.format_column(%{name: "uid", null: false, primary_key: true, type: :bytea})
    assert "      add :avatar_id, :integer\n" == Table.format_column(%{name: "avatar_id", type: :integer})
  end
end
