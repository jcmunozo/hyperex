defmodule HyperexTest do
  use ExUnit.Case

  test "the application and its supervision tree are running" do
    # The :hyperex application is started for the test run; assert it's up.
    assert List.keymember?(Application.started_applications(), :hyperex, 0)

    # The named supervisor from Hyperex.start/2 should be alive.
    assert is_pid(Process.whereis(Hyperex.Supervisor))
  end
end
