defmodule WorkflowEngine.Actions.ApiTest do
  use ExUnit.Case, async: true
  use OK.Pipe

  import Mox

  setup :verify_on_exit!

  describe "API Action - Call Validation" do
    test "fails when missing entity parameter" do
      {:error, error} =
        build_workflow(nil, "create", [])
        |> WorkflowEngine.evaluate()

      assert error =~ "Missing required step parameter \"entity\""
    end

    test "fails when given nonexistent 'entity' param" do
      {:error, error} =
        build_workflow("nonexistent", "create", [])
        |> WorkflowEngine.evaluate()

      assert error =~ "doesn't exist"
    end

    test "fails when given non-entity api module" do
      {:error, error} =
        build_workflow("internal_api", "get", [])
        |> WorkflowEngine.evaluate()

      assert error =~ "not a valid BXDK API module"
    end

    test "fails when missing 'operation' param" do
      {:error, error} =
        build_workflow("tags", nil, [])
        |> WorkflowEngine.evaluate()

      assert error =~ "Missing required step parameter \"operation\""
    end

    test "fails when given nonexistent function" do
      {:error, error} =
        build_workflow("tags", "incarcerate", [])
        |> WorkflowEngine.evaluate()

      assert error =~ "doesn't exist"
    end

    test "fails when missing 'args' param" do
      {:error, error} =
        build_workflow("tags", "get", nil)
        |> WorkflowEngine.evaluate()

      assert error =~ "Missing required step parameter \"args\""
    end

    test "fails when calling function with wrong arity" do
      {:error, error} =
        build_workflow("tags", "get", [])
        |> WorkflowEngine.evaluate()

      assert error =~ "BXDK.Tags.get/0 doesn't exist"
    end

    test "fails when args logic doesn't return a list" do
      {:error, error} =
        build_workflow("tags", "get", %{})
        |> WorkflowEngine.evaluate()

      assert error =~ "Args logic must return a list"
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

    test "returns error for non-existent BXDK entity" do
      {:error, error} =
        build_workflow("asset", "audit", ["a1234567", true])
        |> WorkflowEngine.evaluate()

      assert error =~ "ApiAction: BXDK entity \"Asset\" doesn't exist"
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
