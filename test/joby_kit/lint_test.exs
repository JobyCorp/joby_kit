defmodule JobyKit.LintTest do
  use ExUnit.Case, async: false

  alias JobyKit.Lint
  alias JobyKit.Test.LintFixtures.{BadManifest, GoodManifest}

  setup do
    # The same Code.ensure_loaded! dance manifest_test uses — generator
    # tests can purge support modules.
    Code.ensure_loaded!(JobyKit.Test.LintFixtures.GoodComponents)
    Code.ensure_loaded!(JobyKit.Test.LintFixtures.BadComponents)
    Code.ensure_loaded!(GoodManifest)
    Code.ensure_loaded!(BadManifest)
    :ok
  end

  describe "clean manifest" do
    test "returns no violations when only the well-formed component is registered and no strays exist on disk" do
      violations =
        Lint.run(manifest: GoodManifest, paths: ["test/support/lint_fixtures.ex"])

      # The fixture file also contains BadComponents (with stray_pill and
      # naked_button which aren't in GoodManifest), so unregistered_wrapper
      # *will* fire here. Filter it out to assert the per-entry checks
      # are all clean for good_button.
      per_entry =
        Enum.reject(violations, &(&1.rule == :unregistered_wrapper))

      assert per_entry == []
    end
  end

  describe "manifest_drift" do
    test "fires when an entry points at a function that does not exist" do
      violations = Lint.run(manifest: BadManifest, paths: [])

      drift = Enum.find(violations, &(&1.rule == :manifest_drift))
      assert drift, "expected manifest_drift violation"
      assert drift.severity == :error
      assert drift.module == JobyKit.Test.LintFixtures.BadComponents
      assert drift.function == :ghost_function
      assert drift.message =~ "ghost_function"
    end

    test "drifted entries are skipped for downstream per-entry checks" do
      # ghost_function is drifted. It must NOT also produce a
      # missing_data_component or missing_rest_global violation, since
      # those would be noise on top of the real drift error.
      violations = Lint.run(manifest: BadManifest, paths: [])

      ghost_violations =
        Enum.filter(violations, &(&1.function == :ghost_function))

      assert length(ghost_violations) == 1
      assert hd(ghost_violations).rule == :manifest_drift
    end
  end

  describe "missing_data_component" do
    test "fires when a registered wrapper omits data-component on its root" do
      violations = Lint.run(manifest: BadManifest, paths: [])

      missing =
        Enum.find(violations, fn v ->
          v.rule == :missing_data_component and v.function == :naked_button
        end)

      assert missing, "expected missing_data_component for naked_button"
      assert missing.severity == :error

      assert missing.message =~
               "JobyKit.Test.LintFixtures.BadComponents.naked_button"
    end
  end

  describe "missing_rest_global" do
    test "fires when a registered wrapper does not declare attr :rest, :global" do
      violations = Lint.run(manifest: BadManifest, paths: [])

      missing =
        Enum.find(violations, fn v ->
          v.rule == :missing_rest_global and v.function == :naked_button
        end)

      assert missing
      assert missing.severity == :warning
      assert missing.message =~ "missing `attr :rest, :global`"
    end

    test "does not fire for wrappers that correctly declare it" do
      violations =
        Lint.run(manifest: GoodManifest, paths: ["test/support/lint_fixtures.ex"])

      refute Enum.any?(violations, &(&1.rule == :missing_rest_global))
    end
  end

  describe "unregistered_wrapper" do
    test "fires for functions that emit data-component but are not in the manifest" do
      violations =
        Lint.run(
          manifest: GoodManifest,
          paths: ["test/support/lint_fixtures.ex"]
        )

      unregistered = Enum.filter(violations, &(&1.rule == :unregistered_wrapper))

      data_components = Enum.map(unregistered, &extract_dc/1)

      assert "JobyKit.Test.LintFixtures.BadComponents.stray_pill" in data_components
    end

    test "ignores wrappers that ARE registered" do
      violations =
        Lint.run(
          manifest: GoodManifest,
          paths: ["test/support/lint_fixtures.ex"]
        )

      data_components =
        violations
        |> Enum.filter(&(&1.rule == :unregistered_wrapper))
        |> Enum.map(&extract_dc/1)

      refute "JobyKit.Test.LintFixtures.GoodComponents.good_button" in data_components
    end

    test "deduplicates: a data-component that appears twice in the source produces one violation" do
      tmp = Path.join(System.tmp_dir!(), "joby_kit_lint_dup_#{System.unique_integer([:positive])}.ex")

      File.write!(tmp, """
      defmodule JobyKit.Test.LintFixtures.Twice do
        def a(_), do: ~s|<x data-component="Some.Module.foo"/>|
        def b(_), do: ~s|<y data-component="Some.Module.foo"/>|
      end
      """)

      try do
        violations = Lint.run(manifest: GoodManifest, paths: [tmp])

        matching =
          Enum.filter(violations, fn v ->
            v.rule == :unregistered_wrapper and
              v.message =~ "Some.Module.foo"
          end)

        assert length(matching) == 1
      after
        File.rm!(tmp)
      end
    end

    test "reports a line number from the file" do
      violations =
        Lint.run(
          manifest: GoodManifest,
          paths: ["test/support/lint_fixtures.ex"]
        )

      stray =
        Enum.find(violations, fn v ->
          v.rule == :unregistered_wrapper and
            v.message =~ "stray_pill"
        end)

      assert stray
      assert is_integer(stray.line)
      assert stray.line > 0
    end
  end

  defp extract_dc(violation) do
    case Regex.run(~r/^([\w.]+) carries/, violation.message) do
      [_, dc] -> dc
      _ -> nil
    end
  end

  describe "raw_html_primitive" do
    setup do
      tmp = Path.join(System.tmp_dir!(), "joby_kit_raw_#{System.unique_integer([:positive])}")
      File.mkdir_p!(tmp)
      on_exit(fn -> File.rm_rf!(tmp) end)
      {:ok, tmp: tmp}
    end

    test "fires on raw <button> in a .heex template", %{tmp: tmp} do
      path = Path.join(tmp, "page.heex")
      File.write!(path, ~S"""
      <div>
        <button class="btn">Click me</button>
      </div>
      """)

      violations = Lint.run(manifest: GoodManifest, paths: [path])

      raw =
        Enum.filter(violations, &(&1.rule == :raw_html_primitive))

      assert [%{severity: :warning, line: 2, file: ^path}] = raw
      assert hd(raw).message =~ "<button>"
      assert hd(raw).message =~ "<.button>"
    end

    test "fires on raw <input>, <textarea>, <select> in a ~H block", %{tmp: tmp} do
      path = Path.join(tmp, "live.ex")

      File.write!(path, """
      defmodule Demo do
        use Phoenix.Component

        def render(assigns) do
          ~H\"\"\"
          <input name="x" />
          <textarea></textarea>
          <select></select>
          \"\"\"
        end
      end
      """)

      violations = Lint.run(manifest: GoodManifest, paths: [path])
      raw = Enum.filter(violations, &(&1.rule == :raw_html_primitive))

      tags =
        raw
        |> Enum.map(fn v ->
          [_, t] = Regex.run(~r/raw <(\w+)>/, v.message)
          t
        end)
        |> Enum.sort()

      assert tags == ~w(input select textarea)
    end

    test "skips files that contain data-component= (wrapper territory)", %{tmp: tmp} do
      path = Path.join(tmp, "core_components.ex")

      File.write!(path, """
      defmodule Demo.CoreComponents do
        use Phoenix.Component
        attr :rest, :global
        slot :inner_block, required: true

        def button(assigns) do
          ~H\"\"\"
          <button data-component="Demo.CoreComponents.button" {@rest}>
            {render_slot(@inner_block)}
          </button>
          \"\"\"
        end
      end
      """)

      violations = Lint.run(manifest: GoodManifest, paths: [path])
      assert Enum.filter(violations, &(&1.rule == :raw_html_primitive)) == []
    end

    test "skips .ex files without ~H sigils (no template content)", %{tmp: tmp} do
      path = Path.join(tmp, "task.ex")
      File.write!(path, ~S"""
      defmodule Mix.Tasks.Demo do
        # The string literal mentions `<button>` for help text but there
        # is no ~H block — the rule should skip this file entirely.
        @help "Use <.button> instead of <button class=\"...\">."
        def help, do: @help
      end
      """)

      violations = Lint.run(manifest: GoodManifest, paths: [path])
      assert Enum.filter(violations, &(&1.rule == :raw_html_primitive)) == []
    end

    test "respects per-line opt-out via jobykit:allow-raw-html on same line", %{tmp: tmp} do
      path = Path.join(tmp, "page.heex")
      File.write!(path, ~S"""
      <div>
        <button class="btn">x</button> <%!-- jobykit:allow-raw-html --%>
      </div>
      """)

      violations = Lint.run(manifest: GoodManifest, paths: [path])
      assert Enum.filter(violations, &(&1.rule == :raw_html_primitive)) == []
    end

    test "respects per-line opt-out via jobykit:allow-raw-html on preceding line", %{tmp: tmp} do
      path = Path.join(tmp, "page.heex")
      File.write!(path, ~S"""
      <div>
        <%!-- jobykit:allow-raw-html --%>
        <button class="btn">x</button>
      </div>
      """)

      violations = Lint.run(manifest: GoodManifest, paths: [path])
      assert Enum.filter(violations, &(&1.rule == :raw_html_primitive)) == []
    end

    test "ignores raw-tag mentions that appear inside Elixir string literals",
         %{tmp: tmp} do
      path = Path.join(tmp, "live.ex")

      File.write!(path, """
      defmodule Demo do
        use Phoenix.Component

        @msg "Don't write `<button class=\\\"btn\\\">` when `<.button>` exists."

        def render(assigns) do
          ~H\"\"\"
          <p>{@msg}</p>
          \"\"\"
        end
      end
      """)

      violations = Lint.run(manifest: GoodManifest, paths: [path])
      assert Enum.filter(violations, &(&1.rule == :raw_html_primitive)) == []
    end
  end
end
