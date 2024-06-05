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

    test "download CSV with http action with redirect" do
      {:ok, result} =
        WorkflowEngine.evaluate(%{
          "steps" => [
            %{
              "type" => "http",
              "url" =>
                "https://drive.google.com/uc?id=1zO8ekHWx9U7mrbx_0Hoxxu6od7uxJqWw&export=download",
              "follow_redirects" => true,
              "result" => %{"as" => "csv_data"}
            },
            %{
              "type" => "parse_csv",
              "csv_settings" => %{
                "linebreak" => "\n",
                "separator" => ",",
                "decimal" => "."
              },
              "data" => %{
                "var" => "csv_data"
              },
              "result" => %{"as" => "result"}
            }
          ]
        })
        ~> WorkflowEngine.State.get_var("result")
        ~> Enum.to_list()

      assert length(result) > 0
    end

    test "download CSV with http action with failing redirect" do
      {:ok, result} =
        WorkflowEngine.evaluate(%{
          "steps" => [
            %{
              "type" => "http",
              "url" =>
                "https://drive.google.com/uc?id=1zO8ekHWx9U7mrbx_0Hoxxu6od7uxJqWw&export=download",
              "follow_redirects" => false,
              "result" => %{"as" => "csv_data"}
            },
            %{
              "type" => "parse_csv",
              "csv_settings" => %{
                "linebreak" => "\n",
                "separator" => ",",
                "decimal" => "."
              },
              "data" => %{
                "var" => "csv_data"
              },
              "result" => %{"as" => "result"}
            }
          ]
        })
        ~> WorkflowEngine.State.get_var("result")
        ~> Enum.to_list()

      assert length(result) == 0
    end

    test "Pass url with bad SSL certificate" do
      {:ok, result} =
        WorkflowEngine.evaluate(%{
          "steps" => [
            %{
              "type" => "http",
              "url" => "https://expired.badssl.com/",
              "verify_ssl" => false,
              "result" => %{"as" => "csv_data"}
            }
          ]
        })
        ~> WorkflowEngine.State.get_var("result")
    end

    test "Reject url with bad SSL certificate" do
      {:error, result} =
        WorkflowEngine.evaluate(%{
          "steps" => [
            %{
              "type" => "http",
              "url" => "https://expired.badssl.com/",
              "result" => %{"as" => "csv_data"},
              "max_retries" => 0
            }
          ]
        })
        ~> WorkflowEngine.State.get_var("result")
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
