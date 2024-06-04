defmodule WorkflowEngine.Actions.ParseCsvTest do
  use ExUnit.Case, async: true
  use OK.Pipe

  import Mox

  alias WorkflowEngine.Actions.ParseCsv
  alias WorkflowEngine.Error

  setup :verify_on_exit!

  describe "CSV Action" do
    test "Parse CSV with comma" do
      {:ok, result} =
        build_workflow(",")
        |> WorkflowEngine.evaluate(
          params: %{
            "csv_data" => "name,age\nJohn,30\nJane,25"
          }
        )
        ~> WorkflowEngine.State.get_var("content_rows")
        ~> Enum.to_list()

      assert result == [
               %{"name" => "John", "age" => "30"},
               %{"name" => "Jane", "age" => "25"}
             ]
    end

    test "Parse CSV with semicolon" do
      {:ok, result} =
        build_workflow(";")
        |> WorkflowEngine.evaluate(
          params: %{
            "csv_data" => "name;age\nJohn;30\nJane;25"
          }
        )
        ~> WorkflowEngine.State.get_var("content_rows")
        ~> Enum.to_list()

      assert result == [
               %{"name" => "John", "age" => "30"},
               %{"name" => "Jane", "age" => "25"}
             ]
    end

    test "Parse CSV with tab" do
      {:ok, result} =
        build_workflow("\t")
        |> WorkflowEngine.evaluate(
          params: %{
            "csv_data" => "name\tage\nJohn\t30\nJane\t25"
          }
        )
        ~> WorkflowEngine.State.get_var("content_rows")
        ~> Enum.to_list()

      assert result == [
               %{"name" => "John", "age" => "30"},
               %{"name" => "Jane", "age" => "25"}
             ]
    end
  end

  defp build_workflow(separator) do
    %{
      "steps" => [
        %{
          "type" => "parse_csv",
          "data" => %{
            "var" => "params.csv_data"
          },
          "csv_settings" => %{
            "linebreak" => "\n",
            "separator" => separator,
            "decimal" => "."
          },
          "result" => %{"as" => "content_rows"}
        }
      ]
    }
  end
end
