ExUnit.start()

Mox.defmock(BXDKTagsMock, for: BXDK.Tags)
Application.put_env(:bxdk, BXDK.Tags, BXDKTagsMock)
