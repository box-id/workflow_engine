defmodule WorkflowEngine.Actions.Http do
  @moduledoc """
  Executes a request against an HTTP endpoint.

  See workflow_language.md for documentation.
  """
  use OK.Pipe

  @behaviour WorkflowEngine.Action

  alias WorkflowEngine.State

  require Logger

  @impl WorkflowEngine.Action
  def execute(state, %{"type" => "http"} = step) do
    method = get_method(step)
    url = get_url(step, state)
    params = get_params(step, state)
    auth = get_auth(step, state)
    {body, body_type} = get_body(step, state)
    headers = get_headers(step, body_type)

    request =
      Req.new(
        method: method,
        url: url,
        follow_redirects: false,
        auth: auth,
        body: body,
        headers: headers
      )
      # We use our own `params` step because we want to use a different serializer & allow
      # passthrough of binary param strings.
      |> put_params(params)

    request
    |> Req.request()
    |> unwrap_response(request)
    ~> then(&{state, &1})
  rescue
    # Wrap all error messages & add current state
    e in WorkflowEngine.Error ->
      reraise WorkflowEngine.Error,
              [message: "HttpAction: " <> e.message, state: state],
              __STACKTRACE__
  end

  defp get_method(step) do
    Map.get(step, "method", "GET")
    |> String.upcase()
    |> case do
      "GET" -> :get
      "POST" -> :post
      "PUT" -> :put
      "PATCH" -> :patch
      "DELETE" -> :delete
      method -> raise WorkflowEngine.Error, message: "Invalid HTTP method \"#{method}\"."
    end
  end

  defp get_url(step, state) do
    url =
      try do
        get_required(step, "url")
        |> URI.new!()
      rescue
        e in URI.Error ->
          raise WorkflowEngine.Error,
            message: "Invalid URL: #{URI.Error.message(e)}."
      end

    path = get_path(step, state)

    URI.merge(url, path)
    |> validate_host()
  end

  defp get_path(step, state) do
    case Map.get(step, "path") do
      path when is_binary(path) ->
        path

      path when is_list(path) ->
        State.run_json_logic(state, path)
        |> Enum.join("/")

      nil ->
        ""

      other ->
        raise WorkflowEngine.Error,
          message: "Invalid path: #{inspect(other)}."
    end
  end

  defp validate_host(%URI{scheme: scheme, host: hostname} = uri) do
    case get_allowed_hosts() do
      nil ->
        uri

      allowlist ->
        target = "#{scheme}://#{hostname}"

        allowed? =
          allowlist
          |> String.split(",")
          |> Enum.any?(fn pattern ->
            ExMinimatch.match(pattern, target)
          end)

        if allowed? do
          uri
        else
          raise WorkflowEngine.Error,
            message: "Target \"#{target}\" has not been explicitly allowed."
        end
    end
  end

  defp get_allowed_hosts,
    do:
      Process.get(:_workflow_allowed_http_hosts_during_test) ||
        System.get_env("WORKFLOW_ALLOWED_HTTP_HOSTS")

  defp get_params(step, state) do
    case Map.get(step, "params") do
      params when is_map(params) ->
        State.run_json_logic(state, params)

      params when is_binary(params) ->
        params

      nil ->
        %{}

      # We currently do not support mixed params in a list because of the post-processing that
      # would be required.
      # params when is_list(params) ->
      #   State.run_json_logic(state, params) |> TODO!

      params ->
        raise WorkflowEngine.Error,
          message: "Invalid params: #{inspect(params)}"
    end
  end

  defp get_required(step, key) do
    case Map.fetch(step, key) do
      {:ok, value} when not is_nil(value) ->
        value

      _ ->
        raise WorkflowEngine.Error,
          message: "Missing required step parameter \"#{key}\"."
    end
  end

  defp get_headers(%{"headers" => headers}, body_type) do
    custom_headers =
      case headers do
        headers when is_map(headers) ->
          # Downcase header names
          Map.new(headers, fn {k, v} -> {String.downcase(k), v} end)

        nil ->
          %{}

        other ->
          raise WorkflowEngine.Error,
            message: "Invalid headers: #{inspect(other)}"
      end

    Map.merge(default_headers(body_type), custom_headers)
  end

  defp get_headers(_, body_type), do: default_headers(body_type)

  defp default_headers(body_type),
    do: %{"accept" => "application/json"} |> add_content_type_header(body_type)

  defp add_content_type_header(headers, :json),
    do: Map.put(headers, "content-type", "application/json")

  defp add_content_type_header(headers, _), do: headers

  defp get_auth(%{"auth_token" => token}, state) do
    case token do
      token when is_binary(token) ->
        {:bearer, token}

      token_logic ->
        {:bearer, State.run_json_logic(state, token_logic)}
    end
  end

  defp get_auth(_, _), do: nil

  defp get_body(step, state) do
    case Map.get(step, "body") do
      body when is_map(body) or is_list(body) ->
        json =
          State.run_json_logic(state, body)
          |> Jason.encode!()

        {json, :json}

      body when is_binary(body) ->
        {body, :binary}

      nil ->
        {nil, :none}

      body ->
        raise WorkflowEngine.Error,
          message: "Invalid body: #{inspect(body)}"
    end
  end

  defp put_params(request, params) when params in [nil, %{}, []], do: request

  defp put_params(request, params) when is_map(params) do
    # Use Plug's encoder which supports array values.
    encoded = Plug.Conn.Query.encode(params)

    put_params(request, encoded)
  end

  defp put_params(request, params) when is_binary(params) do
    update_in(request.url.query, fn
      nil -> params
      query -> query <> "&" <> params
    end)
  end

  @spec unwrap_response({:error, Mint.TransportError.t()} | {:ok, Req.Response.t()}, any) ::
          {:error, {atom, any}} | {:ok, any}
  def unwrap_response({:ok, %Req.Response{status: status, body: body}}, req) do
    if status < 400 do
      {:ok, body}
    else
      Logger.warning(
        "HttpAction: #{req_to_string(req)} failed with status #{status}: #{inspect(body)}"
      )

      status_atom = Plug.Conn.Status.reason_atom(status)
      {:error, {status_atom, body}}
    end
  end

  def unwrap_response({:error, %Mint.TransportError{} = error}, req) do
    message = Mint.TransportError.message(error)

    Logger.warning("HttpAction: #{req_to_string(req)} failed: #{message}")

    details = %{
      "error" => "ENETWORK",
      "message" => message,
      "status" => 0
    }

    {:error, {:network_error, details}}
  end

  defp req_to_string(%Req.Request{method: method, options: options, url: url}) do
    merged_url = URI.merge(Map.get(options, :base_url, ""), url)

    "#{String.upcase(Atom.to_string(method))} #{URI.to_string(merged_url)}"
  end
end
