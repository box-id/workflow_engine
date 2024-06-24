defmodule WorkflowEngine.Actions.HTTPTest do
  use ExUnit.Case, async: false
  use OK.Pipe

  import ExUnit.CaptureLog

  alias WorkflowEngine.Error

  defmodule __MODULE__.JsonLogic do
    use JsonLogic.Base,
      extensions: [JsonLogic.Extensions.Obj]
  end

  setup do
    bypass = Bypass.open()
    bypass_base_url = "http://localhost:#{bypass.port}/"

    Process.put(
      :_workflow_allowed_http_hosts_during_test,
      "http://localhost,https://expired.badssl.com"
    )

    {:ok, bypass: bypass, url: bypass_base_url}
  end

  describe "HTTP Action - URL Validation" do
    test "fails when missing 'url' param" do
      assert_raise Error, ~r/Missing required step parameter "url"/, fn ->
        build_workflow()
        |> WorkflowEngine.evaluate()
      end
    end

    test "fails when given invalid 'url' param" do
      assert_raise Error, ~r/Invalid URL/, fn ->
        build_workflow(%{"url" => "not a url"})
        |> WorkflowEngine.evaluate()
      end
    end

    test "fails when given 'url' that is not allow-listed" do
      assert_raise Error, ~r/has not been explicitly allowed/, fn ->
        build_workflow(%{"url" => "https://test.example.com"})
        |> WorkflowEngine.evaluate()
      end
    end

    test "performs request against valid URL and path", %{bypass: bypass, url: url} do
      Bypass.expect_once(bypass, "GET", "/", fn conn ->
        send_json(conn, %{foo: 42})
      end)

      build_workflow(%{"url" => url})
      |> WorkflowEngine.evaluate()
    end
  end

  describe "HTTP Action - Path" do
    test "accepts path as binary", %{bypass: bypass, url: url} do
      Bypass.expect_once(bypass, "GET", "/some/path", fn conn ->
        send_json(conn, %{foo: 42})
      end)

      build_workflow(%{"url" => url, "path" => "/some/path"})
      |> WorkflowEngine.evaluate()
    end

    test "accepts path as list of JsonLogic expressions", %{bypass: bypass, url: url} do
      Bypass.expect_once(bypass, "GET", "/some/fixed/path/5", fn conn ->
        send_json(conn, %{foo: 42})
      end)

      build_workflow(%{
        "url" => url,
        "path" => [
          %{"var" => "params.someVar"},
          "fixed",
          %{"var" => "params.pathVar"},
          5
        ]
      })
      |> WorkflowEngine.evaluate(
        params: %{"someVar" => "some", "pathVar" => "path"},
        json_logic: __MODULE__.JsonLogic
      )
    end

    test "fails when given invalid 'path'", %{url: url} do
      assert_raise Error, ~r/Invalid path/, fn ->
        build_workflow(%{"url" => url, "path" => %{"some" => "map"}})
        |> WorkflowEngine.evaluate()
      end
    end

    test "defaults to / when given explicit NULL path", %{bypass: bypass, url: url} do
      Bypass.expect_once(bypass, "GET", "/", fn conn ->
        send_json(conn, %{foo: 42})
      end)

      build_workflow(%{"url" => url, "path" => nil})
      |> WorkflowEngine.evaluate()
    end

    test "value is appended to path of `url`", %{bypass: bypass, url: url} do
      Bypass.expect_once(bypass, "GET", "/path/from/url/and/path", fn conn ->
        send_json(conn, %{foo: 42})
      end)

      build_workflow(%{"url" => url <> "/path/from/url/", "path" => "./and/path"})
      |> WorkflowEngine.evaluate()
    end
  end

  describe "HTTP Action - Headers" do
    test "fails when given invalid 'headers'", %{url: url} do
      assert_raise Error, ~r/Invalid headers/, fn ->
        build_workflow(%{"url" => url, "headers" => "not a map"})
        |> WorkflowEngine.evaluate()
      end
    end

    test "sends accept JSON header by default", %{bypass: bypass, url: url} do
      Bypass.expect_once(bypass, "GET", "/", fn conn ->
        # Assert that by default, JSON content is requested
        assert {"accept", "application/json"} in conn.req_headers

        send_json(conn, %{foo: 42})
      end)

      build_workflow(%{"url" => url})
      |> WorkflowEngine.evaluate()
    end

    test "merges in additional headers", %{bypass: bypass, url: url} do
      Bypass.expect_once(bypass, "GET", "/", fn conn ->
        # Allows overriding the default headers
        assert {"accept", "application/xml"} in conn.req_headers
        # Also asserts that header name is downcased
        assert {"x-my-header", "never gonna give you up"} in conn.req_headers

        send_json(conn, %{foo: 42})
      end)

      build_workflow(%{
        "url" => url,
        "headers" => %{"ACCEPT" => "application/xml", "X-My-Header" => "never gonna give you up"}
      })
      |> WorkflowEngine.evaluate()
    end
  end

  describe "HTTP Action - Auth" do
    test "sends static auth_token as bearer token", %{bypass: bypass, url: url} do
      Bypass.expect_once(bypass, "GET", "/", fn conn ->
        assert {"authorization", "Bearer MyToken123"} in conn.req_headers

        send_json(conn, %{foo: 42})
      end)

      build_workflow(%{"url" => url, "auth_token" => "MyToken123"})
      |> WorkflowEngine.evaluate()
    end

    test "evaluates JsonLogic auth_token", %{bypass: bypass, url: url} do
      Bypass.expect_once(bypass, "GET", "/", fn conn ->
        assert {"authorization", "Bearer MyToken123"} in conn.req_headers

        send_json(conn, %{foo: 42})
      end)

      build_workflow(%{"url" => url, "auth_token" => %{"var" => "params.user_token"}})
      |> WorkflowEngine.evaluate(params: %{"user_token" => "MyToken123"})
    end
  end

  describe "HTTP Action - Method" do
    test "sends GET by default", %{bypass: bypass, url: url} do
      Bypass.expect_once(bypass, "GET", "/", fn conn ->
        send_json(conn, %{foo: 42})
      end)

      build_workflow(%{"url" => url})
      |> WorkflowEngine.evaluate()
    end

    test "sends POST when specified", %{bypass: bypass, url: url} do
      Bypass.expect_once(bypass, "POST", "/", fn conn ->
        send_json(conn, %{foo: 42})
      end)

      build_workflow(%{"url" => url, "method" => "PosT"})
      |> WorkflowEngine.evaluate()
    end

    test "sends PUT when specified", %{bypass: bypass, url: url} do
      Bypass.expect_once(bypass, "PUT", "/", fn conn ->
        send_json(conn, %{foo: 42})
      end)

      build_workflow(%{"url" => url, "method" => "put"})
      |> WorkflowEngine.evaluate()
    end

    test "sends PATCH when specified", %{bypass: bypass, url: url} do
      Bypass.expect_once(bypass, "PATCH", "/", fn conn ->
        send_json(conn, %{foo: 42})
      end)

      build_workflow(%{"url" => url, "method" => "PATCH"})
      |> WorkflowEngine.evaluate()
    end

    test "sends DELETE when specified", %{bypass: bypass, url: url} do
      Bypass.expect_once(bypass, "DELETE", "/", fn conn ->
        send_json(conn, %{foo: 42})
      end)

      build_workflow(%{"url" => url, "method" => "DELETE"})
      |> WorkflowEngine.evaluate()
    end

    test "fails when given invalid 'method'", %{url: url} do
      assert_raise Error, ~r/Invalid HTTP method/, fn ->
        build_workflow(%{"url" => url, "method" => "not a method"})
        |> WorkflowEngine.evaluate()
      end
    end
  end

  describe "HTTP Action - Params" do
    test "sends query params when given as static map", %{bypass: bypass, url: url} do
      Bypass.expect_once(bypass, "GET", "/", fn conn ->
        assert %{"foo" => "bar", "baz" => "qux"} = conn.query_params

        send_json(conn, %{foo: 42})
      end)

      build_workflow(%{"url" => url, "params" => %{"foo" => "bar", "baz" => "qux"}})
      |> WorkflowEngine.evaluate()
    end

    test "sends query params when given as JsonLogic", %{bypass: bypass, url: url} do
      Bypass.expect_once(bypass, "GET", "/", fn conn ->
        assert %{"foo" => "fooVal", "bar" => "barVal", "arrayParam" => ["foo", "bar"]} =
                 conn.query_params

        send_json(conn, %{foo: 42})
      end)

      build_workflow(%{
        "url" => url,
        "params" => %{
          "obj" => [
            ["foo", %{"var" => "params.foo"}],
            ["bar", %{"var" => "params.bar"}],
            %{"arrayParam" => ["foo", "bar"]}
          ]
        }
      })
      |> WorkflowEngine.evaluate(
        params: %{"foo" => "fooVal", "bar" => "barVal"},
        json_logic: __MODULE__.JsonLogic
      )
    end

    test "sends query params when given as string", %{bypass: bypass, url: url} do
      Bypass.expect_once(bypass, "GET", "/", fn conn ->
        assert %{"foo" => "fooVal", "bar" => "barVal", "arr" => ["1", "2"]} = conn.query_params

        send_json(conn, %{foo: 42})
      end)

      build_workflow(%{
        "url" => url,
        "params" => "foo=fooVal&bar=barVal&arr[]=1&arr[]=2"
      })
      |> WorkflowEngine.evaluate()
    end

    test "merges params with params present in URL", %{bypass: bypass, url: url} do
      Bypass.expect_once(bypass, "GET", "/", fn conn ->
        assert %{"foo" => "bar", "baz" => "qux"} = conn.query_params

        send_json(conn, %{foo: 42})
      end)

      build_workflow(%{
        "url" => url <> "?foo=bar",
        "params" => %{"obj" => %{"baz" => "qux"}}
      })
      |> WorkflowEngine.evaluate(json_logic: __MODULE__.JsonLogic)
    end
  end

  describe "HTTP Action - Body" do
    test "sends static map as JSON body", %{bypass: bypass, url: url} do
      Bypass.expect_once(bypass, "POST", "/", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert %{"foo" => "bar", "baz" => "qux"} = Jason.decode!(body)
        assert {"content-type", "application/json"} in conn.req_headers

        send_json(conn, %{foo: 42})
      end)

      build_workflow(%{
        "url" => url,
        "method" => "POST",
        "body" => %{"foo" => "bar", "baz" => "qux"}
      })
      |> WorkflowEngine.evaluate()
    end

    test "sends JSON body when given a JsonLogic that returns a map", %{bypass: bypass, url: url} do
      Bypass.expect_once(bypass, "POST", "/", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert %{"foo" => "fooVal", "bar" => "barVal"} = Jason.decode!(body)
        assert {"content-type", "application/json"} in conn.req_headers

        send_json(conn, %{foo: 42})
      end)

      build_workflow(%{
        "url" => url,
        "method" => "POST",
        "body" => %{
          "obj" => [
            ["foo", %{"var" => "params.foo"}],
            ["bar", %{"var" => "params.bar"}]
          ]
        }
      })
      |> WorkflowEngine.evaluate(
        params: %{"foo" => "fooVal", "bar" => "barVal"},
        json_logic: __MODULE__.JsonLogic
      )
    end

    test "sends JSON body when given a JsonLogic that returns a list", %{bypass: bypass, url: url} do
      Bypass.expect_once(bypass, "POST", "/", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert ["foo", "fooVal"] = Jason.decode!(body)
        assert {"content-type", "application/json"} in conn.req_headers

        send_json(conn, %{foo: 42})
      end)

      build_workflow(%{
        "url" => url,
        "method" => "POST",
        "body" => ["foo", %{"var" => "params.foo"}]
      })
      |> WorkflowEngine.evaluate(
        params: %{"foo" => "fooVal"},
        json_logic: __MODULE__.JsonLogic
      )
    end

    test "sends contents without content type if given as binary", %{bypass: bypass, url: url} do
      Bypass.expect_once(bypass, "PUT", "/", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert "some pre-encoded content" = body

        refute Enum.find(conn.req_headers, &match?({"content-type", _}, &1))

        send_json(conn, %{foo: 42})
      end)

      build_workflow(%{
        "url" => url,
        "method" => "PUT",
        "body" => "some pre-encoded content"
      })
      |> WorkflowEngine.evaluate()
    end
  end

  describe "HTTP Action - Results" do
    test "returns parsed JSON result", %{bypass: bypass, url: url} do
      Bypass.expect_once(bypass, "GET", "/", fn conn ->
        send_json(conn, %{foo: 42})
      end)

      {:ok, result} =
        build_workflow(%{"url" => url})
        |> WorkflowEngine.evaluate()
        ~> WorkflowEngine.State.get_var("result")

      assert %{"foo" => 42} = result
    end

    test "returns error for error response", %{bypass: bypass, url: url} do
      Bypass.expect_once(bypass, "GET", "/", fn conn ->
        send_json(conn, 400, %{error: "Something went wrong"})
      end)

      Log

      {{:error, error}, log} =
        with_log(fn ->
          build_workflow(%{"url" => url})
          |> WorkflowEngine.evaluate()
        end)

      assert log =~ "failed with status 400"

      assert error =~ "bad_request"
      assert error =~ "Something went wrong"
    end
  end

  describe "HTTP Action - Redirect" do
    test "redirects when parameter is set to true", %{bypass: bypass, url: url} do
      Bypass.expect_once(bypass, "GET", "/", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("location", url <> "redirected")
        |> Plug.Conn.resp(302, "")
      end)

      Bypass.expect_once(bypass, "GET", "/redirected", fn conn ->
        send_json(conn, 200, %{foo: 42})
      end)

      {:ok, result} =
        WorkflowEngine.evaluate(%{
          "steps" => [
            %{
              "type" => "http",
              "url" => url,
              "follow_redirects" => true,
              "result" => %{"as" => "result"}
            }
          ]
        })
        ~> WorkflowEngine.State.get_var("result")

      assert %{"foo" => 42} = result
    end

    test "fails with unallowed redirect", %{bypass: bypass, url: url} do
      Bypass.expect_once(bypass, "GET", "/", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("location", url <> "redirected")
        |> Plug.Conn.resp(302, "Resource can be found...")
      end)

      {:ok, result} =
        WorkflowEngine.evaluate(%{
          "steps" => [
            %{
              "type" => "http",
              "url" => url,
              "follow_redirects" => false,
              "result" => %{"as" => "result"}
            }
          ]
        })
        ~> WorkflowEngine.State.get_var("result")

      assert "Resource can be found..." == result
    end
  end

  describe "HTTP Action - SSL" do
    test "accepts URL with bad certificate" do
      assert {:ok, _result} =
               WorkflowEngine.evaluate(%{
                 "steps" => [
                   %{
                     "type" => "http",
                     "url" => "https://expired.badssl.com/",
                     "allow_insecure" => true,
                     "result" => %{"as" => "result"}
                   }
                 ]
               })
               ~> WorkflowEngine.State.get_var("result")
    end

    test "Reject url with bad SSL certificate" do
      assert {:error, result} =
               WorkflowEngine.evaluate(%{
                 "steps" => [
                   %{
                     "type" => "http",
                     "url" => "https://expired.badssl.com/",
                     "result" => %{"as" => "csv_data"},
                     "max_retries" => 0
                   }
                 ]
               })

      assert result =~ "Certificate Expired"
    end
  end

  defp build_workflow(fields \\ %{}) do
    %{
      "steps" => [
        %{
          "type" => "http",
          "result" => %{"as" => "result"}
        }
        |> Map.merge(fields)
      ]
    }
  end

  defp send_json(conn, status \\ 200, data) do
    conn
    |> Plug.Conn.put_resp_header("content-type", "application/json")
    |> Plug.Conn.resp(status, Jason.encode!(data))
  end
end
