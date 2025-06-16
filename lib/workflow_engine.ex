defmodule WorkflowEngine do
  use OK.Pipe

  alias WorkflowEngine.Actions
  alias WorkflowEngine.State

  @builtin_actions %{
    "http" => Actions.Http,
    "parse_csv" => Actions.ParseCsv
  }

  @spec evaluate(map(), keyword() | map()) :: {:error, any} | {:ok, State.t()}
  def evaluate(workflow, opts_or_state \\ [])

  def evaluate(%State{} = state, %{"steps" => steps}) do
    steps_with_index = steps |> List.wrap() |> Enum.with_index()
    eval_steps(state, steps_with_index)
  rescue
    error ->
      wrap_error(error, state)
  end

  def evaluate(%State{} = state, steps) when is_list(steps) or is_map(steps) do
    steps_with_index = steps |> List.wrap() |> Enum.with_index()
    eval_steps(state, steps_with_index)
  rescue
    error ->
      wrap_error(error, state)
  end

  def evaluate(%State{} = state, _workflow) do
    %WorkflowEngine.Error{
      message: "Unable to get steps from workflow",
      state: state
    }
    |> wrap_error(state)
  end

  def evaluate(workflow, opts) when is_list(opts) do
    state = %State{
      vars: %{
        "params" => Keyword.get(opts, :params, %{})
      },
      json_logic_mod: Keyword.get(opts, :json_logic, JsonLogic),
      actions: Map.merge(@builtin_actions, Keyword.get(opts, :actions, %{}))
    }

    evaluate(state, workflow)
  end

  defp eval_steps(state, [{step, idx} | rest]) do
    state
    |> State.push_ip(idx)
    |> State.set_current_step(step)
    |> eval_step(step)
    ~> State.pop_ip()
    ~>> eval_steps(rest)
  end

  defp eval_steps(state, []) do
    # Just because we're out of steps doesn't mean that we're finished with the whole workflow
    # (could be a sub-workflow)
    if State.instruction_depth(state) == 0 do
      State.finalize(state)
    else
      state
    end
    |> OK.wrap()
  end

  defp eval_step(state, %{"if" => condition, "then" => then_flow} = control) do
    state
    |> State.update_ip(:if)
    |> State.run_json_logic(condition)
    |> if do
      state
      |> State.update_ip({:if, :then})
      |> evaluate(then_flow)
    else
      if else_flow = Map.get(control, "else") do
        state
        |> State.update_ip({:if, :else})
        |> evaluate(else_flow)
      else
        state
        |> OK.wrap()
      end
    end
  end

  defp eval_step(state, %{"loop" => loop_logic, "do" => do_flow} = control) do
    binding_name = Map.fetch(control, "element")

    binding_index_name =
      case binding_name do
        :error -> :error
        {:ok, name} -> "#{name}_index"
      end

    state =
      state
      |> State.update_ip(:loop)
      |> State.snapshot_var(binding_name)
      |> State.snapshot_var(binding_index_name)
      |> State.snapshot_var("loop")

    iterable = State.run_json_logic(state, loop_logic)

    # provide descriptive error if the logic's result is not iterable.
    if Enumerable.impl_for(iterable) == nil do
      raise WorkflowEngine.Error,
        message: "Loop value not iterable.\n\nValue:\n#{inspect(iterable)}",
        state: state
    end

    iterable
    |> Stream.with_index()
    |> Enum.reduce_while(state, fn {iter_item, idx}, state ->
      state
      |> State.update_ip({:loop, idx})
      |> State.put_var(binding_name, iter_item)
      |> State.put_var(binding_index_name, idx)
      |> State.put_var("loop", %{"element" => iter_item, "element_index" => idx})
      |> evaluate(do_flow)
      |> case do
        {:ok, state} -> {:cont, state}
        {:error, _} = error -> {:halt, error}
      end
    end)
    |> OK.wrap()
    ~> State.restore_var(binding_name)
    ~> State.restore_var(binding_index_name)
    ~> State.restore_var("loop")
  end

  defp eval_step(state, %{"yield" => yield_logic}) do
    state = State.update_ip(state, :yield)

    data = State.run_json_logic(state, yield_logic)

    State.yield(state, data)
    |> OK.wrap()
  end

  defp eval_step(state, %{"type" => action_type} = step) do
    state = State.update_ip(state, :action)

    action_mod =
      Map.get(state.actions, action_type) ||
        raise WorkflowEngine.Error,
          message: "Unknown action #{inspect(action_type)}",
          state: state

    # Safe to create atom from action_type because it was listed in the workflow's action map
    state = State.update_ip(state, {:action, String.to_atom(action_type)})

    try do
      action_mod.execute(state, step)
      |> case do
        {:ok, {state, result}} ->
          case Map.fetch(step, "result") do
            {:ok, result_description} ->
              state
              |> State.update_ip({:action, :store_result})
              |> store_result(result, result_description)
              |> OK.wrap()

            :error ->
              {:ok, state}
          end

        {:error, %{recoverable: recoverable} = reason} ->
          wrap_error(reason, state, recoverable: recoverable)

        {:error, reason} ->
          wrap_error(reason, state, recoverable: true)
      end
    rescue
      error ->
        wrap_error(error, state)
    end
  end

  defp eval_step(state, step) do
    raise WorkflowEngine.Error,
      message: "Step instructions not recognized:\n#{inspect(step)}",
      state: state
  end

  defp store_result(state, result, %{"transform" => transform_logic} = description) do
    transformed_result =
      state
      |> State.put_var("action", %{"result" => result})
      |> State.run_json_logic(transform_logic)

    store_result(state, transformed_result, Map.delete(description, "transform"))
  end

  defp store_result(state, result, %{"as" => binding_name}) when is_binary(binding_name) do
    State.put_var(state, binding_name, result)
  end

  defp store_result(state, _result, _description) do
    raise WorkflowEngine.Error,
      message: "Result description missing or invalid 'as'.",
      state: state
  end

  # Some errors are already in a format that we can use when they're rescued during execution
  defp wrap_error(error, state, opts \\ [])

  defp wrap_error(%WorkflowEngine.Error{} = error, _state, opts),
    do:
      %{
        error
        | recoverable: Keyword.get(opts, :recoverable, false)
      }
      |> OK.failure()

  defp wrap_error(error, state, opts),
    do:
      %WorkflowEngine.Error{
        message: "Workflow action failed with reason:\n#{inspect(error)}",
        state: state
      }
      |> wrap_error(state, opts)
end
