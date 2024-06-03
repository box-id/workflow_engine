defmodule WorkflowEngine.Actions.ParseCsvTest do
  use ExUnit.Case, async: true
  use OK.Pipe

  import Mox

  alias WorkflowEngine.Actions.ParseCsv
  alias WorkflowEngine.Error

  setup :verify_on_exit!

  describe "CSV Action" do
    test "test" do
      {:ok, result} =
        build_workflow()
        |> WorkflowEngine.evaluate()

      IO.inspect(result)
    end
  end

  defp build_workflow() do
    %{
      "steps" => [
        %{
          "type" => "csv",
          "blob" => "name,age\nJohn,30\nJane,25",
          "csv_settings" => %{
            "linebreak" => "\n",
            "delimiter" => ",",
            "decimal" => "."
          }
        }
      ]
    }
  end
end
