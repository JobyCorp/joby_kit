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

      # The fixture file also contains BadComponents (stray_pill and
      # naked_button, neither in GoodManifest), so unregistered_wrapper and
      # raw_html_primitive both fire against it. Filter those out to assert
      # the per-entry checks are all clean for good_button.
      per_entry =
        Enum.reject(violations, &(&1.rule in [:unregistered_wrapper, :raw_html_primitive]))

      assert per_entry == []
    end

    test "a wrapper's own raw primitive is not flagged inside its def" do
      violations = Lint.run(manifest: GoodManifest, paths: ["test/support/lint_fixtures.ex"])

      raw = Enum.filter(violations, &(&1.rule == :raw_html_primitive))

      # good_button/1 carries data-component, so the <button> in its body is
      # the wrapper's own markup — exempt.
      refute Enum.any?(raw, &(&1.line in 10..14)),
             "good_button's own <button> should be wrapper territory"
    end

    test "raw primitives are caught in a file that also defines wrappers" do
      # The regression this rule exists for. lint_fixtures.ex defines two
      # components carrying data-component, which under the old whole-file
      # exemption silenced the rule for the entire file — including
      # naked_button/1, whose whole point is to be a violation. Scoping the
      # exemption to the enclosing def restores coverage for the rest.
      violations = Lint.run(manifest: GoodManifest, paths: ["test/support/lint_fixtures.ex"])

      naked =
        Enum.find(violations, &(&1.rule == :raw_html_primitive and &1.line == 28))

      assert naked, "expected the raw <button> in naked_button/1 to be reported"
      assert naked.message =~ "raw <button>"
      assert naked.file == "test/support/lint_fixtures.ex"
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

  # Every case below was a reported false positive or a miss. The fixtures
  # live in test/support/lint_cases/ so they're real files on disk, scanned
  # the way a host's tree is.

  describe "raw_html_primitive: false positives" do
    test "commented-out markup is not live markup" do
      violations = run_on("comments.heex")

      assert Enum.filter(violations, &(&1.rule == :raw_html_primitive)) == [],
             "HEEx and HTML comments should not be flagged"
    end

    test "a docstring describing the rule is not a violation of it" do
      # The kit's own composite_components.ex template says "never raw
      # `<button>`/`<input>`/`<textarea>`" in its moduledoc. Scanning docs
      # made every freshly installed host open with three warnings quoting
      # the very sentence telling them not to do it.
      path = Path.join(System.tmp_dir!(), "lint_doc_mentions_tags.ex")

      File.write!(path, ~S'''
      defmodule DocMentions do
        @moduledoc """
        Internals compose the kit wrappers — never raw
        `<button>`/`<input>`/`<textarea>`.
        """
        use Phoenix.Component

        def thing(assigns) do
          ~H"""
          <span data-component="DocMentions.thing">x</span>
          """
        end
      end
      ''')

      on_exit(fn -> File.rm(path) end)

      violations = Lint.run(manifest: GoodManifest, paths: [path])
      assert Enum.filter(violations, &(&1.rule == :raw_html_primitive)) == []
    end

    test "capitalised remote components are not raw HTML tags" do
      # HEEx reserves lowercase for HTML and capitalised for components, so
      # <Input.autocomplete /> is a component call. The old case-insensitive
      # regex flagged any host with a component module named Input/Select.
      violations = run_on("remote_components.heex")

      assert Enum.filter(violations, &(&1.rule == :raw_html_primitive)) == []
    end
  end

  describe "raw_html_primitive: misses" do
    test "every primitive on a line is reported, not just the first" do
      raw = run_on("multiple_per_line.heex") |> Enum.filter(&(&1.rule == :raw_html_primitive))

      tags = raw |> Enum.map(& &1.message) |> Enum.join(" ")
      assert length(raw) == 2, "expected both <input> and <select> on the line"
      assert tags =~ "raw <input>"
      assert tags =~ "raw <select>"
    end
  end

  describe "forked_wrapper" do
    test "flags kit components excluded from the import" do
      violations = run_on("forked_web.ex")
      forks = Enum.filter(violations, &(&1.rule == :forked_wrapper))

      assert length(forks) == 2
      assert Enum.map(forks, & &1.function) |> Enum.sort() == [:button, :table]

      fork = hd(forks)
      assert fork.severity == :warning
      assert fork.message =~ "will not reach it"
      assert fork.file =~ "forked_web.ex"
    end

    test "a plain kit import is not a fork" do
      path = Path.join(System.tmp_dir!(), "lint_plain_import.ex")
      File.write!(path, "defmodule P do\n  import JobyKit.CoreComponents\nend\n")
      on_exit(fn -> File.rm(path) end)

      violations = Lint.run(manifest: GoodManifest, paths: [path])
      assert Enum.filter(violations, &(&1.rule == :forked_wrapper)) == []
    end
  end

  describe "duplicated_class_string" do
    test "flags a long class string repeated past the threshold" do
      violations = run_on("duplicated_classes.heex")
      dupes = Enum.filter(violations, &(&1.rule == :duplicated_class_string))

      assert [dupe] = dupes
      assert dupe.message =~ "appears 3 times"
      assert dupe.message =~ "duplicated_classes.heex:"
      assert dupe.severity == :warning
    end

    test "short class strings are left alone" do
      violations = run_on("duplicated_classes.heex")
      dupes = Enum.filter(violations, &(&1.rule == :duplicated_class_string))

      refute Enum.any?(dupes, &(&1.message =~ "text-sm"))
    end

    test "two uses are under the threshold" do
      path = Path.join(System.tmp_dir!(), "lint_two_uses.heex")

      File.write!(path, """
      <p class="font-mono text-[0.68rem] uppercase tracking-[0.2em] text-base-content/50">a</p>
      <p class="font-mono text-[0.68rem] uppercase tracking-[0.2em] text-base-content/50">b</p>
      """)

      on_exit(fn -> File.rm(path) end)

      violations = Lint.run(manifest: GoodManifest, paths: [path])
      assert Enum.filter(violations, &(&1.rule == :duplicated_class_string)) == []
    end
  end

  describe "docstring prose is not a contract" do
    test "a data-component described in a moduledoc is not an unregistered wrapper" do
      # Confirmed live: the shipped composite_components.ex template spells
      # the attribute out in its moduledoc, so every freshly installed host
      # opened with a phantom warning for a component literally named
      # `<name>`.
      path = Path.join(System.tmp_dir!(), "lint_docstring_prose.ex")

      File.write!(path, ~S'''
      defmodule DocProse do
        @moduledoc """
        Every composite must carry
        `data-component="MyAppWeb.CompositeComponents.<name>"` on its root.
        """
        use Phoenix.Component

        def thing(assigns) do
          ~H"""
          <span data-component="DocProse.thing">x</span>
          """
        end
      end
      ''')

      on_exit(fn -> File.rm(path) end)

      violations = Lint.run(manifest: GoodManifest, paths: [path])
      names = violations |> Enum.filter(&(&1.rule == :unregistered_wrapper)) |> Enum.map(& &1.message)

      refute Enum.any?(names, &(&1 =~ "<name>")), "docstring prose should not register as a wrapper"
      assert Enum.any?(names, &(&1 =~ "DocProse.thing")), "the real wrapper should still be flagged"
    end
  end

  defp run_on(fixture) do
    Lint.run(manifest: GoodManifest, paths: ["test/support/lint_cases/#{fixture}"])
  end
end
