defmodule WorkflowEngine.Actions.ApiTest do
  use ExUnit.Case, async: true
  use OK.Pipe

  import Mox

  alias WorkflowEngine.Error

  setup :verify_on_exit!

  describe "API Action - Call Validation" do
    test "fails when missing entity parameter" do
      assert_raise Error, ~r/Missing required step parameter "entity"/, fn ->
        build_workflow(nil, "create", [])
        |> WorkflowEngine.evaluate()
      end
    end

    test "fails when given nonexistent 'entity' param" do
      assert_raise Error, ~r/doesn't exist/, fn ->
        build_workflow("nonexistent", "create", [])
        |> WorkflowEngine.evaluate()
      end
    end

    test "fails when given non-entity api module" do
      assert_raise Error, ~r/not a valid BXDK API module/, fn ->
        build_workflow("internal_api", "get", [])
        |> WorkflowEngine.evaluate()
      end
    end

    test "fails when missing 'operation' param" do
      assert_raise Error, ~r/Missing required step parameter "operation"/, fn ->
        build_workflow("tags", nil, [])
        |> WorkflowEngine.evaluate()
      end
    end

    test "fails when given nonexistent function" do
      assert_raise Error, ~r/doesn't exist/, fn ->
        build_workflow("tags", "incarcerate", [])
        |> WorkflowEngine.evaluate()
      end
    end

    test "fails when missing 'args' param" do
      assert_raise Error, ~r/Missing required step parameter "args"/, fn ->
        build_workflow("tags", "get", nil)
        |> WorkflowEngine.evaluate()
      end
    end

    test "fails when calling function with wrong arity" do
      assert_raise Error, ~r/BXDK\.Tags\.get\/0 doesn't exist/, fn ->
        build_workflow("tags", "get", [])
        |> WorkflowEngine.evaluate()
      end
    end

    test "fails when args logic doesn't return a list" do
      assert_raise Error, ~r/Args logic must return a list/, fn ->
        build_workflow("tags", "get", %{})
        |> WorkflowEngine.evaluate()
      end
    end
  end

  describe "API Action - Results" do
    test "returns ok result for success result" do
      BXDKTagsMock
      |> expect(:get, fn _params -> {:ok, %{"id" => 1, "name" => "Test Tag"}} end)

      {:ok, result} =
        build_workflow("tags", "get", [1])
        |> WorkflowEngine.evaluate()
        ~> WorkflowEngine.State.get_var("result")

      assert result == %{"id" => 1, "name" => "Test Tag"}
    end

    test "returns ok result for stream result" do
      BXDKTagsMock
      |> expect(:get, fn _params ->
        Stream.cycle([%{"id" => 1, "name" => "Test Tag"}]) |> Stream.take(1)
      end)

      {:ok, result} =
        build_workflow("tags", "get", [1])
        |> WorkflowEngine.evaluate()
        ~> WorkflowEngine.State.get_var("result")
        # |> IO.inspect(label: "result")

      assert Enum.to_list(result) == [%{"id" => 1, "name" => "Test Tag"}]
    end

    test "returns error for error result" do
      BXDKTagsMock
      |> expect(:get, fn _params -> {:error, "Something went wrong"} end)

      {:error, error} =
        build_workflow("tags", "get", [1])
        |> WorkflowEngine.evaluate()

      assert error =~ "Something went wrong"
    end
  end

  defp build_workflow(entity, operation, args) do
    %{
      "steps" => [
        %{
          "type" => "api",
          "entity" => entity,
          "operation" => operation,
          "args" => args,
          "result" => %{"as" => "result"}
        }
      ]
    }
  end
end
