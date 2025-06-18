ExUnit.configure(exclude: [:external_service])
ExUnit.start()

Mox.defmock(ActionMock, for: WorkflowEngine.Action)
