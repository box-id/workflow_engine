defmodule WorkflowEngineTest do
  @moduledoc false
  use ExUnit.Case, async: true
  use OK.Pipe

  import Mox

  alias WorkflowEngine
  alias WorkflowEngine.State

  setup :verify_on_exit!

  test "empty workflow succeeds" do
    WorkflowEngine.evaluate(%{"steps" => []})
  end

  describe "yield" do
    test "simple yield works" do
      assert {:ok, [42]} =
               WorkflowEngine.evaluate(%{
                 "steps" => [
                   %{"yield" => 42}
                 ]
               })
               ~> State.get_yielded()
    end

    test "values of multiple yields are collected" do
      assert {:ok, [4, 8, 15]} =
               WorkflowEngine.evaluate(%{
                 "steps" => [
                   %{"yield" => 4},
                   %{"yield" => 8},
                   %{"yield" => 15}
                 ]
               })
               ~> State.get_yielded()
    end

    test "conditionally nested yield" do
      assert {:ok, [42]} =
               WorkflowEngine.evaluate(%{
                 "steps" => [
                   %{
                     "if" => true,
                     "then" => [
                       %{
                         "if" => false,
                         "then" => :illegal_workflow,
                         "else" => [
                           %{"yield" => 42}
                         ]
                       }
                     ]
                   }
                 ]
               })
               ~> State.get_yielded()
    end

    # This one isn't really a requirement but I wanted to "document" the current behavior
    test "yield doesn't flatten array values" do
      assert {:ok, [[1, 2, 3]]} =
               WorkflowEngine.evaluate(%{
                 "steps" => [
                   %{"yield" => [1, 2, 3]}
                 ]
               })
               ~> State.get_yielded()
    end
  end

  describe "if" do
    test "correctly evaluates then branch" do
      assert {:ok, ["success"]} =
               WorkflowEngine.evaluate(%{
                 "steps" => [
                   %{
                     "if" => true,
                     "then" => %{
                       "steps" => [%{"yield" => "success"}]
                     }
                   }
                 ]
               })
               ~> State.get_yielded()
    end

    test "evaluates then branch when given as list of steps" do
      assert {:ok, ["success"]} =
               WorkflowEngine.evaluate(%{
                 "steps" => [
                   %{
                     "if" => true,
                     "then" => [%{"yield" => "success"}]
                   }
                 ]
               })
               ~> State.get_yielded()
    end

    test "evaluates then branch when given as single step" do
      assert {:ok, ["success"]} =
               WorkflowEngine.evaluate(%{
                 "steps" => [
                   %{
                     "if" => true,
                     "then" => %{"yield" => "success"}
                   }
                 ]
               })
               ~> State.get_yielded()
    end

    test "evaluates then branch based on logic" do
      assert {:ok, ["then"]} =
               WorkflowEngine.evaluate(%{
                 "steps" => [
                   %{
                     "if" => %{"or" => [true, false]},
                     "then" => %{"yield" => "then"}
                   }
                 ]
               })
               ~> State.get_yielded()
    end

    test "evaluates else branch based on logic" do
      assert {:ok, ["else"]} =
               WorkflowEngine.evaluate(%{
                 "steps" => [
                   %{
                     "if" => %{"and" => [true, false]},
                     "then" => %{"yield" => "then"},
                     "else" => %{"yield" => "else"}
                   }
                 ]
               })
               ~> State.get_yielded()
    end

    test "doesn't fail if else branch is selected but doesn't exist" do
      assert {:ok, []} =
               WorkflowEngine.evaluate(%{
                 "steps" => [
                   %{
                     "if" => false,
                     "then" => %{"yield" => "then"}
                   }
                 ]
               })
               ~> State.get_yielded()
    end

    # TODO: Test nested context
  end

  describe "loop" do
    test "looped workflow has access to variable-bound loop element" do
      assert {:ok, ["a", "b", "c"]} =
               WorkflowEngine.evaluate(%{
                 "steps" => [
                   %{
                     "loop" => ["a", "b", "c"],
                     "element" => "value",
                     "do" => %{"yield" => %{"var" => "value"}}
                   }
                 ]
               })
               ~> State.get_yielded()
    end

    test "looped workflow has access to variable-bound loop element index" do
      assert {:ok, [0, 1, 2]} =
               WorkflowEngine.evaluate(%{
                 "steps" => [
                   %{
                     "loop" => ["a", "b", "c"],
                     "element" => "value",
                     "do" => %{"yield" => %{"var" => "value_index"}}
                   }
                 ]
               })
               ~> State.get_yielded()
    end

    test "looped workflow has access to loop element through context" do
      assert {:ok, ["a", "b", "c"]} =
               WorkflowEngine.evaluate(%{
                 "steps" => [
                   %{
                     "loop" => ["a", "b", "c"],
                     "do" => %{"yield" => %{"var" => "loop.element"}}
                   }
                 ]
               })
               ~> State.get_yielded()
    end

    test "looped workflow has access to loop element index through context" do
      assert {:ok, [0, 1, 2]} =
               WorkflowEngine.evaluate(%{
                 "steps" => [
                   %{
                     "loop" => ["a", "b", "c"],
                     "element" => "value",
                     "do" => %{"yield" => %{"var" => "loop.element_index"}}
                   }
                 ]
               })
               ~> State.get_yielded()
    end

    test "loop doesn't leak 'loop' var" do
      {:ok, state} =
        WorkflowEngine.evaluate(%{
          "steps" => [
            %{
              "loop" => ["a", "b", "c"],
              "do" => []
            }
          ]
        })

      refute Map.get(state.vars, "loop")
    end

    test "loop restores bound variable" do
      assert {:ok, ["some_val", "some_val"]} =
               %State{vars: %{"my_val" => "some_val"}}
               |> WorkflowEngine.evaluate(%{
                 "steps" => [
                   %{"yield" => %{"var" => "my_val"}},
                   %{
                     "loop" => ["a", "b", "c"],
                     "element" => "my_val",
                     "do" => []
                   },
                   %{"yield" => %{"var" => "my_val"}}
                 ]
               })
               ~> State.get_yielded()
    end

    test "loops streams" do
      assert {:ok, ["a", "b", "a"]} =
               %State{vars: %{"stream_data" => Stream.cycle(["a", "b"]) |> Stream.take(3)}}
               |> WorkflowEngine.evaluate(%{
                 "steps" => [
                   %{
                     "loop" => %{"var" => "stream_data"},
                     "do" => %{"yield" => %{"var" => "loop.element"}}
                   }
                 ]
               })
               ~> State.get_yielded()
    end

    test "fails with appropriate error if value is not iterable" do
      {:error, error} =
        WorkflowEngine.evaluate(%{
          "steps" => [
            %{
              "loop" => "some_string",
              "do" => []
            }
          ]
        })

      assert error.recoverable == false
      assert error.message =~ "Loop value not iterable"
    end
  end

  describe "actions" do
    test "fails with appropriate error if action is unknown" do
      {:error, error} =
        WorkflowEngine.evaluate(%{
          "steps" => [
            %{
              "type" => "foo",
              "do" => []
            }
          ]
        })

      assert error.recoverable == false
      assert error.message =~ "Unknown action \"foo\""
    end

    test "allows extension by passing action map as option" do
      ActionMock
      |> expect(:execute, fn state, %{"data" => data} -> {:ok, {state, data}} end)

      assert {:ok, ["expected result"]} =
               WorkflowEngine.evaluate(
                 %{
                   "steps" => [
                     %{
                       "type" => "echo_action",
                       "data" => "expected result",
                       "result" => %{
                         "as" => "foo_result"
                       }
                     },
                     %{"yield" => %{"var" => "foo_result"}}
                   ]
                 },
                 actions: %{"echo_action" => ActionMock}
               )
               ~> State.get_yielded()
    end

    test "extension actions report error results with correct instruction pointer & message" do
      ActionMock
      |> expect(:execute, fn _state, _step -> {:error, "Oops!"} end)

      assert {:error, error} =
               WorkflowEngine.evaluate(
                 %{
                   "steps" => [
                     %{
                       "type" => "echo_action"
                     }
                   ]
                 },
                 actions: %{"echo_action" => ActionMock}
               )
               ~> State.get_yielded()

      assert Exception.message(error) =~ "{:action, :echo_action}"
      assert Exception.message(error) =~ "Oops!"
    end

    test "allows storing result in variable" do
      ActionMock
      |> expect(:execute, fn state, %{"data" => data} -> {:ok, {state, data}} end)

      assert {:ok, %{"key" => "data"}} =
               WorkflowEngine.evaluate(
                 %{
                   "steps" => [
                     %{
                       "type" => "echo_action",
                       "data" => %{"key" => "data"},
                       "result" => %{
                         "as" => "foo_result"
                       }
                     }
                   ]
                 },
                 actions: %{"echo_action" => ActionMock}
               )
               ~> State.get_var("foo_result")
    end

    test "allows storing result in variable with JsonLogic transform" do
      ActionMock
      |> expect(:execute, fn state, %{"data" => data} -> {:ok, {state, data}} end)

      assert {:ok, "data_suffix"} =
               WorkflowEngine.evaluate(
                 %{
                   "steps" => [
                     %{
                       "type" => "echo_action",
                       "data" => %{"key" => "data"},
                       "result" => %{
                         "as" => "foo_result",
                         "transform" => %{
                           "cat" => [
                             %{"var" => "action.result.key"},
                             "_suffix"
                           ]
                         }
                       }
                     }
                   ]
                 },
                 actions: %{"echo_action" => ActionMock}
               )
               ~> State.get_var("foo_result")
    end
  end
end
