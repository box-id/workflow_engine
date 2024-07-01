defmodule WorkflowEngine.Actions.DocumentAiTest do
  use ExUnit.Case, async: true
  use OK.Pipe

  alias WorkflowEngine.Actions.DocumentAi

  describe "test" do
    test "test" do
      DocumentAi.execute(%{}, %{
        "type" => "document_ai",
        "model_id" => "rekord-fenster-delivery-note",
        "document_url" =>
          "https://images.box-id.com/insecure/w:0/h:0/el:t/rt:fit/g:ce:0:0/aHR0cHM6Ly9zMy5ldS1jZW50cmFsLTEuYW1hem9uYXdzLmNvbTo0NDMvbWVkaWFib3hpZC9iMjM2NzYxY2IyODM3Y2M0ZWU2YzU1NzdhNDA1MWI3OQ==.jpg"
      })
    end
  end
end
