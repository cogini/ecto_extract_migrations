defmodule EctoExtractMigrations do
  @moduledoc """
  The main entry point is lib/mix/tasks/ecto_extract_migrations.ex
  This module mainly has common library functions.
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

  @doc "Convert SQL name to Elixir module name"
  @spec format_module_name(binary | list(binary)) :: binary
  def format_module_name(table) when is_binary(table), do: Macro.camelize(table)
  def format_module_name(["public", table]), do: Macro.camelize(table)
  def format_module_name([schema, table]) do
    "#{Macro.camelize(schema)}.#{Macro.camelize(table)}"
  end

  @doc "Make result of calling NimbleParsec parser easier to deal with"
  @spec unwrap_result(tuple) :: {:ok, term} | {:error, term}
  def unwrap_result(result) do
    case result do
      {:ok, [acc], "", _, _line, _offset} ->
        {:ok, acc}

      {:ok, _, rest, _, _line, _offset} ->
        {:error, "could not parse: " <> rest}

      {:error, reason, _rest, _context, _line, _offset} ->
        {:error, reason}
    end
  end
end
