defmodule Mix.Tasks.JobyKit.LintTest do
  use ExUnit.Case, async: false

  alias JobyKit.Test.LintFixtures.{BadManifest, GoodManifest}

  # The engine is covered in JobyKit.LintTest; this file covers the task
  # wrapper — exit codes, formatters, and manifest resolution. Every host's
  # CLAUDE.md tells agents to run `mix joby_kit.lint` before claiming done,
  # so a formatter or exit-code regression breaks that loop everywhere at
  # once while the engine tests stay green.

  setup do
    Code.ensure_loaded!(JobyKit.Test.LintFixtures.GoodComponents)
    Code.ensure_loaded!(JobyKit.Test.LintFixtures.BadComponents)
    Code.ensure_loaded!(GoodManifest)
    Code.ensure_loaded!(BadManifest)

    shell = Mix.shell()
    Mix.shell(Mix.Shell.Process)
    on_exit(fn -> Mix.shell(shell) end)

    :ok
  end

  defp run(args), do: Mix.Tasks.JobyKit.Lint.run(args)

  # Mix prints its own `==> app` project banner through the shell, and with
  # Mix.Shell.Process that lands in this mailbox interleaved with the task's
  # output. It appears once per run, so whichever test happens to go first
  # under a given seed inherits it — which made the JSON tests fail on some
  # seeds and not others. Drop it; it is never task output.
  defp drain_output do
    receive do
      {:mix_shell, :info, [msg]} -> [msg | drain_output()]
    after
      0 -> []
    end
    |> Enum.reject(&String.starts_with?(&1, "==> "))
  end

  defp output(args) do
    run(args)
    Enum.join(drain_output(), "\n")
  end

  describe "clean run" do
    test "returns :ok and says so" do
      # No paths to scan, so only the per-entry checks run — GoodManifest
      # passes all of them.
      assert :ok == run(["--manifest", inspect(GoodManifest), "--paths", "test/support/none"])

      assert Enum.join(drain_output(), "\n") =~ "Clean"
    end

    test "names the manifest it linted" do
      out = output(["--manifest", inspect(GoodManifest), "--paths", "test/support/none"])

      assert out =~ inspect(GoodManifest)
    end
  end

  describe "exit codes" do
    test "exits non-zero when there is an error-severity violation" do
      # BadManifest carries a :manifest_drift error.
      assert catch_exit(run(["--manifest", inspect(BadManifest), "--paths", "test/support/none"])) ==
               {:shutdown, 1}
    end

    test "warnings alone do not fail the run" do
      # Scanning the fixture file surfaces unregistered_wrapper warnings
      # against GoodManifest, but no errors.
      assert :ok ==
               run([
                 "--manifest",
                 inspect(GoodManifest),
                 "--paths",
                 "test/support/lint_fixtures.ex"
               ])
    end

    test "--strict promotes warnings to failures" do
      assert catch_exit(
               run([
                 "--manifest",
                 inspect(GoodManifest),
                 "--paths",
                 "test/support/lint_fixtures.ex",
                 "--strict"
               ])
             ) == {:shutdown, 1}
    end
  end

  describe "text formatter" do
    test "prints rule, message, location, and a pluralized summary" do
      out =
        output([
          "--manifest",
          inspect(GoodManifest),
          "--paths",
          "test/support/lint_fixtures.ex"
        ])

      assert out =~ "unregistered_wrapper"
      assert out =~ "WARN"
      assert out =~ "test/support/lint_fixtures.ex:"
      assert out =~ ~r/Summary: \d+ warnings?/
    end

    test "summary counts errors separately from warnings" do
      catch_exit(
        output([
          "--manifest",
          inspect(BadManifest),
          "--paths",
          "test/support/lint_fixtures.ex"
        ])
      )

      out = Enum.join(drain_output(), "\n")
      assert out =~ "ERROR"
    end
  end

  describe "json formatter" do
    test "emits a decodable payload with manifest, violations, and summary" do
      out =
        output([
          "--manifest",
          inspect(GoodManifest),
          "--paths",
          "test/support/lint_fixtures.ex",
          "--format",
          "json"
        ])

      payload = Jason.decode!(out)

      assert payload["manifest"] == inspect(GoodManifest)
      assert is_list(payload["violations"])
      assert payload["summary"]["warnings"] == length(payload["violations"])
      assert payload["summary"]["errors"] == 0

      violation = hd(payload["violations"])
      assert violation["rule"] == "unregistered_wrapper"
      assert violation["severity"] == "warning"
      assert violation["file"] =~ "lint_fixtures.ex"
      assert is_integer(violation["line"])
    end

    test "a clean run still emits valid json" do
      out =
        output([
          "--manifest",
          inspect(GoodManifest),
          "--paths",
          "test/support/none",
          "--format",
          "json"
        ])

      assert %{"violations" => [], "summary" => %{"errors" => 0, "warnings" => 0}} =
               Jason.decode!(out)
    end
  end

  describe "argument handling" do
    test "rejects an unknown --format" do
      assert_raise Mix.Error, ~r/unknown --format/, fn ->
        run([
          "--manifest",
          inspect(GoodManifest),
          "--paths",
          "test/support/none",
          "--format",
          "yaml"
        ])
      end
    end

    test "raises a helpful error when the manifest module cannot be loaded" do
      assert_raise Mix.Error, ~r/could not be loaded/, fn ->
        run(["--manifest", "Nope.NotAManifest"])
      end
    end

    test "--paths is repeatable" do
      out =
        output([
          "--manifest",
          inspect(GoodManifest),
          "--paths",
          "test/support/none",
          "--paths",
          "test/support/lint_fixtures.ex"
        ])

      # The second path still gets scanned.
      assert out =~ "unregistered_wrapper"
    end
  end
end
