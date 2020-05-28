defmodule EctoExtractMigrations do
  @moduledoc """
  Documentation for `EctoExtractMigrations`.
  """

  defmodule ParseError do
    defexception message: "default message"
  end

  @doc "Evaluate template file with bindings"
  @spec eval_template(Path.t(), Keyword.t()) :: {:ok, binary} | {:error, term}
  def eval_template(template_file, bindings \\ []) do
    {:ok, EEx.eval_file(template_file, bindings, trim: true)}
  rescue
    e ->
      {:error, {:template, e}}
  end
end
