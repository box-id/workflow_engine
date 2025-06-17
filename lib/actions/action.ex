defmodule WorkflowEngine.Action do
  @moduledoc """
  Behavior that describes the necessary methods for an workflow action.
  """

  alias WorkflowEngine.State

  @callback execute(state :: State.t(), step :: map()) ::
              {:ok, {State.t(), any()}} | {:error, any()}
end
