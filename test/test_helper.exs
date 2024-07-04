ExUnit.configure(exclude: [:external_service_skip])
ExUnit.start()

Mox.defmock(BXDKTagsMock, for: BXDK.Tags)
Application.put_env(:bxdk, BXDK.Tags, BXDKTagsMock)

Mox.defmock(ActionMock, for: WorkflowEngine.Action)
