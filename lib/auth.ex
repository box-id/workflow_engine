defmodule WorkflowEngine.Auth do
  @moduledoc """
  Optional behaviour for providing authentication to workflow actions.

  `use WorkflowEngine.Auth` in a module and override `authenticate/2` to supply credentials per
  action type.
  """

  alias WorkflowEngine.State

  @doc """
  Called to fetch authentication for an action.

  ## Parameters
    * `type`: the step's `"type"` string (e.g. `"http"`)
    * `target`: action-specific target

  ## Return values
    * `{:ok, nil}`: no authentication
    * `{:ok, auth}`: action-specific auth value (e.g. `{:bearer, "token"}`)
    * `{:error, reason}`: authentication failed
  """
  @callback authenticate(type :: binary(), target :: any()) :: {:ok, any()} | {:error, any()}

  @optional_callbacks [authenticate: 2]

  defmacro __using__(_opts) do
    quote do
      @behaviour WorkflowEngine.Auth

      @impl WorkflowEngine.Auth
      def authenticate(_type, _target), do: {:ok, nil}

      defoverridable authenticate: 2
    end
  end

  @doc """
  Fetches authentication for the given action type and target using the
  configured `auth` callback module on the state.

  Returns `{:ok, nil}` if no callback is configured.
  """
  @spec get_auth(State.t(), String.t(), any()) :: {:ok, any()} | {:error, any()}
  def get_auth(%State{auth: nil}, _type, _target), do: {:ok, nil}
  def get_auth(%State{} = state, type, target), do: state.auth.authenticate(type, target)
end
