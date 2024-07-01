defmodule WorkflowEngine.Actions.DocumentAiTest do
  use ExUnit.Case, async: true
  use OK.Pipe

  alias WorkflowEngine.Actions.DocumentAi

  defmodule __MODULE__.JsonLogic do
    use JsonLogic.Base,
      extensions: [JsonLogic.Extensions.Obj]
  end

  describe "Document AI" do
    test "Params in body" do
      DocumentAi.execute(%{}, %{
        "type" => "document_ai",
        "model_id" => "rekord-fenster-delivery-note",
        "document_url" =>
          "https://images.box-id.com/insecure/w:0/h:0/el:t/rt:fit/g:ce:0:0/aHR0cHM6Ly9zMy5ldS1jZW50cmFsLTEuYW1hem9uYXdzLmNvbTo0NDMvbWVkaWFib3hpZC9iMjM2NzYxY2IyODM3Y2M0ZWU2YzU1NzdhNDA1MWI3OQ==.jpg"
      })
    end

    test "Params in JSON logic" do
      build_workflow(%{
        "model_id" => %{
          "var" => "params.model_id"
        },
        "document_url" => %{
          "var" => "params.document_url"
        }
      })
      |> WorkflowEngine.evaluate(
        params: %{
          "model_id" => "rekord-fenster-delivery-note",
          "document_url" =>
            "https://images.box-id.com/insecure/w:0/h:0/el:t/rt:fit/g:ce:0:0/aHR0cHM6Ly9zMy5ldS1jZW50cmFsLTEuYW1hem9uYXdzLmNvbTo0NDMvbWVkaWFib3hpZC9iMjM2NzYxY2IyODM3Y2M0ZWU2YzU1NzdhNDA1MWI3OQ==.jpg"
        },
        json_logic: __MODULE__.JsonLogic
      )
    end
  end

  defp build_workflow(fields \\ %{}) do
    %{
      "steps" => [
        %{
          "type" => "document_ai",
          "result" => %{"as" => "result"}
        }
        |> Map.merge(fields)
      ]
    }
  end
end
