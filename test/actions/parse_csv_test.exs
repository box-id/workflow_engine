defmodule WorkflowEngine.Actions.ParseCsvTest do
  use ExUnit.Case, async: true
  use OK.Pipe

  import Mox

  setup :verify_on_exit!

  describe "Parse CSV Action" do
    test "Parse CSV with comma" do
      {:ok, result} =
        build_workflow(csv_settings: [separator: ","])
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

    test "Parse CSV with comma using alias for separator option" do
      {:ok, result} =
        build_workflow(csv_settings: [separator: "comma"])
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
        build_workflow(csv_settings: [separator: ";"])
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
        build_workflow(csv_settings: [separator: "\t"])
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
        build_workflow()
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
        build_workflow()
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
        build_workflow()
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
        build_workflow()
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
        build_workflow()
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

    test "Parse pre-split CSV with BOM character" do
      {:ok, result} =
        build_workflow()
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

  describe "Parse CSV Action - Columns option" do
    test "uses manually supplied columns of header-less CSV with number of fields matching" do
      {:ok, result} =
        build_workflow(columns: ["name", "age"])
        |> WorkflowEngine.evaluate(
          params: %{
            "csv_data" => "John,30\nJane,25\n"
          }
        )
        ~> WorkflowEngine.State.get_var("content_rows")
        ~> Enum.to_list()

      assert result == [
               %{"name" => "John", "age" => "30"},
               %{"name" => "Jane", "age" => "25"}
             ]
    end

    test "uses manually supplied columns, cutting off extra data fields" do
      {:ok, result} =
        build_workflow(columns: ["name", "age"])
        |> WorkflowEngine.evaluate(
          params: %{
            "csv_data" => "John,30,Plumber\nJane,25,Electrician"
          }
        )
        ~> WorkflowEngine.State.get_var("content_rows")
        ~> Enum.to_list()

      assert result == [
               %{"name" => "John", "age" => "30"},
               %{"name" => "Jane", "age" => "25"}
             ]
    end

    test "Manually supplied columns with missing data fields" do
      {:ok, result} =
        build_workflow(columns: ["name", "age", "profession"])
        |> WorkflowEngine.evaluate(
          params: %{
            "csv_data" => "John,30\nJane,25\n"
          }
        )
        ~> WorkflowEngine.State.get_var("content_rows")
        ~> Enum.to_list()

      assert result == [
               %{"name" => "John", "age" => "30", "profession" => nil},
               %{"name" => "Jane", "age" => "25", "profession" => nil}
             ]
    end

    test "Manually supplied columns and skip_header option" do
      {:ok, result} =
        build_workflow(columns: ["name", "age"], csv_settings: [skip_header: true])
        |> WorkflowEngine.evaluate(
          params: %{
            "csv_data" => "Vorname,Alter\nJohn,30\nJane,25\n"
          }
        )
        ~> WorkflowEngine.State.get_var("content_rows")
        ~> Enum.to_list()

      assert result == [
               %{"name" => "John", "age" => "30"},
               %{"name" => "Jane", "age" => "25"}
             ]
    end

    test "fails when given invalid separator" do
      {:error, reason} =
        build_workflow(csv_settings: [separator: "foo"])
        |> WorkflowEngine.evaluate(
          params: %{
            "csv_data" => "name,age\nJohn,30\nJane,25"
          }
        )

      assert reason =~ "Invalid CSV separator"
    end
  end

  defp build_workflow(opts \\ []) do
    %{
      "steps" => [
        %{
          "type" => "parse_csv",
          "data" => %{
            "var" => "params.csv_data"
          },
          "result" => %{"as" => "content_rows"}
        }
        |> deep_merge(to_binary_map(opts))
      ]
    }
  end

  # Depp-convert maps and keyword lists to maps with binary keys.
  defp to_binary_map(map) do
    Map.new(map, fn {k, v} ->
      {Atom.to_string(k),
       if(is_map(v) or match?([{_k, _v} | _], v), do: to_binary_map(v), else: v)}
    end)
  end

  defp deep_merge(map1, map2) do
    Map.merge(map1, map2, fn
      _key, v1, v2 when is_map(v1) and is_map(v2) -> deep_merge(v1, v2)
      _key, _v1, v2 -> v2
    end)
  end
end
