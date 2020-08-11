defmodule CommentTest do
  use ExUnit.Case

  alias EctoExtractMigrations.Parsers.Comment

  test "parse" do
    assert {:ok, %{comment: "Some text"}} == Comment.parse("-- Some text\n")
    assert {:ok, %{comment: "Some text"}} == Comment.parse("    -- Some text\n")
    assert {:ok, %{comment: "Some text"}} == Comment.parse("    --Some text\n")
  end
end

