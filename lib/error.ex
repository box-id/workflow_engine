defmodule WorkflowEngine.Error do
  defexception [:message, :state, :recoverable]

  def message(error) do
    """
    #{error.message}

    Instruction Pointer:
    #{format_ip(error.state.instruction_pointer)}
    """ <> format_step(error)
  end

  defp format_step(error) do
    with {:ok, step} <- OK.required(error.state.current_step),
         {:ok, encoded} <- Jason.encode(step, pretty: true) do
      """

      Step Details:
      #{encoded}
      """
    else
      _ -> ""
    end
  end

  defp format_ip(instructions) do
    instructions
    |> Enum.reverse()
    |> Enum.with_index()
    |> Enum.map_join("\n", fn {{step_idx, details}, depth} ->
      "#{indent(depth)}#{step_idx}: #{inspect(details)}"
    end)
  end

  defp indent(idx) when idx > 1 do
    "   " <> indent(idx - 1)
  end

  defp indent(1) do
    "└> "
  end

  defp indent(_), do: ""
end
