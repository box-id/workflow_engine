defmodule WorkflowEngine.StateTest do
  use ExUnit.Case, async: true

  # Alias needed to allow doctest referring to state module as `State`.
  alias WorkflowEngine.State

  doctest WorkflowEngine.State
end
