defmodule WorkflowEngine.Actions.ParseCsvTest do
  use ExUnit.Case, async: true
  use OK.Pipe

  import Mox

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

    test "Parse CSV with empty file" do
      {:ok, result} =
        build_workflow(nil)
        |> WorkflowEngine.evaluate(
          params: %{
            "csv_data" => ""
          }
        )
        ~> WorkflowEngine.State.get_var("content_rows")
        ~> Enum.to_list()

      assert result == []
    end

    test "Parse CSV with utf encoding" do
      {:ok, result} =
        build_workflow(",")
        |> WorkflowEngine.evaluate(
          params: %{
            "csv_data" => "name,age\nJöhn,30\nJäne,25"
          }
        )
        ~> WorkflowEngine.State.get_var("content_rows")
        ~> Enum.to_list()

      assert result == [
               %{"name" => "Jöhn", "age" => "30"},
               %{"name" => "Jäne", "age" => "25"}
             ]
    end

    test "Parse CSV with missing values" do
      {:ok, result} =
        build_workflow(",")
        |> WorkflowEngine.evaluate(
          params: %{
            "csv_data" => "name,age\nJohn,\nJane,25"
          }
        )
        ~> WorkflowEngine.State.get_var("content_rows")
        ~> Enum.to_list()

      assert result == [
               %{"name" => "John", "age" => ""},
               %{"name" => "Jane", "age" => "25"}
             ]
    end

    test "Parse CSV with quotation marks" do
      {:ok, result} =
        build_workflow(",")
        |> WorkflowEngine.evaluate(
          params: %{
            "csv_data" => ~s'name,age\n"""John""",30\nJane,25'
          }
        )
        ~> WorkflowEngine.State.get_var("content_rows")
        ~> Enum.to_list()

      assert result == [
               %{"name" => "\"John\"", "age" => "30"},
               %{"name" => "Jane", "age" => "25"}
             ]
    end

    test "Parse CSV with BOM character" do
      {:ok, result} =
        build_workflow(",")
        |> WorkflowEngine.evaluate(
          params: %{
            "csv_data" => <<239, 187, 191>> <> "name,age\nJohn,30\nJane,25"
          }
        )
        ~> WorkflowEngine.State.get_var("content_rows")
        ~> Enum.to_list()

      assert result == [
               %{"name" => "John", "age" => "30"},
               %{"name" => "Jane", "age" => "25"}
             ]
    end

    test "Parse presplit CSV with BOM character" do
      {:ok, result} =
        build_workflow(",")
        |> WorkflowEngine.evaluate(
          params: %{
            # Not sure if this input format (with newline terminated rows in a list...) is
            # actually used (e.g. in the case of stream-downloading a CSV file via HTTP)
            "csv_data" => [<<239, 187, 191>> <> "name,age\n", "John,30\n", "Jane,25\n"]
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
            "separator" => separator
          },
          "result" => %{"as" => "content_rows"}
        }
      ]
    }
  end
end