defmodule Mix.Tasks.JobyKit.Gen.WrapperTest do
  use ExUnit.Case

  @moduletag :tmp_dir

  describe "core wrapper without --daisy" do
    test "scaffolds component, manifest entry, and preview", %{tmp_dir: tmp_dir} do
      in_installed_project(tmp_dir, fn ->
        Mix.Tasks.JobyKit.Gen.Wrapper.run(["metric_tile"])

        core = File.read!("lib/demo_app_web/components/core_components.ex")
        assert core =~ "def metric_tile(assigns)"
        assert core =~ ~s|data-component="DemoAppWeb.CoreComponents.metric_tile"|
        assert core =~ "attr :rest, :global"
        assert core =~ "slot :inner_block"

        manifest = File.read!("lib/demo_app_web/design_manifest.ex")
        assert manifest =~ "component(DemoAppWeb.CoreComponents, :metric_tile,"
        assert manifest =~ "category: :core"
        assert manifest =~ "preview: &DesignPreviews.metric_tile_preview/1"

        previews = File.read!("lib/demo_app_web/design_previews.ex")
        assert previews =~ "def metric_tile_preview(assigns)"
        # CoreComponents is imported via `use <App>Web, :html` — preview
        # uses the period-form, not the aliased module path.
        assert previews =~ "<.metric_tile>"
        refute previews =~ "<CoreComponents.metric_tile>"
      end)
    end
  end

  describe "core wrapper with --daisy" do
    test "uses the daisy class as the root class and the daisy_basis", %{tmp_dir: tmp_dir} do
      in_installed_project(tmp_dir, fn ->
        Mix.Tasks.JobyKit.Gen.Wrapper.run(["metric_tile", "--daisy", "modal"])

        core = File.read!("lib/demo_app_web/components/core_components.ex")
        assert core =~ ~s|class="modal"|

        manifest = File.read!("lib/demo_app_web/design_manifest.ex")
        assert manifest =~ ~s|daisy_basis: "modal"|
      end)
    end

    test "for compound primitives, uses the first class as root and keeps the full string in daisy_basis",
         %{tmp_dir: tmp_dir} do
      in_installed_project(tmp_dir, fn ->
        # `chat_bubble` has classes "chat / chat-bubble"
        Mix.Tasks.JobyKit.Gen.Wrapper.run(["bubble", "--daisy", "chat_bubble"])

        core = File.read!("lib/demo_app_web/components/core_components.ex")
        assert core =~ ~s|class="chat"|

        manifest = File.read!("lib/demo_app_web/design_manifest.ex")
        assert manifest =~ ~s|daisy_basis: "chat / chat-bubble"|
      end)
    end

    test "rejects unknown daisy ids", %{tmp_dir: tmp_dir} do
      in_installed_project(tmp_dir, fn ->
        assert_raise Mix.Error, ~r/unknown --daisy "fizzbuzz"/, fn ->
          Mix.Tasks.JobyKit.Gen.Wrapper.run(["metric_tile", "--daisy", "fizzbuzz"])
        end
      end)
    end
  end

  describe "composite wrapper" do
    test "creates composite_components.ex if absent and adds an alias to design_previews",
         %{tmp_dir: tmp_dir} do
      in_installed_project(tmp_dir, fn ->
        # Install pre-scaffolds composite_components.ex with an
        # empty_state worked example. Remove it here so we exercise the
        # "create from scratch" path; the appending-to-existing path is
        # covered by a separate test below.
        File.rm!("lib/demo_app_web/components/composite_components.ex")
        refute File.exists?("lib/demo_app_web/components/composite_components.ex")

        Mix.Tasks.JobyKit.Gen.Wrapper.run(["chat_panel", "--category", "composite"])

        comp = File.read!("lib/demo_app_web/components/composite_components.ex")
        assert comp =~ "defmodule DemoAppWeb.CompositeComponents do"
        # `use <App>Web, :html`, not a bare Phoenix.Component: composites
      # compose core wrappers and verified routes.
      assert comp =~ "use DemoAppWeb, :html"
      assert comp =~ "alias JobyKit.CoreComponents"
        assert comp =~ "def chat_panel(assigns)"
        assert comp =~ ~s|data-component="DemoAppWeb.CompositeComponents.chat_panel"|

        manifest = File.read!("lib/demo_app_web/design_manifest.ex")
        assert manifest =~ "component(DemoAppWeb.CompositeComponents, :chat_panel,"
        assert manifest =~ "category: :composite"

        previews = File.read!("lib/demo_app_web/design_previews.ex")
        assert previews =~ ~r/alias DemoAppWeb\.(\{[^}]*CompositeComponents|CompositeComponents)/
        assert previews =~ "def chat_panel_preview(assigns)"
        assert previews =~ "<CompositeComponents.chat_panel>"

        # Manifest uses fully qualified names — no alias needed there.
        manifest = File.read!("lib/demo_app_web/design_manifest.ex")
        assert manifest =~ "component(DemoAppWeb.CompositeComponents, :chat_panel,"
      end)
    end

    test "rejects --daisy for composites", %{tmp_dir: tmp_dir} do
      in_installed_project(tmp_dir, fn ->
        assert_raise Mix.Error, ~r/--daisy is only meaningful with --category core/, fn ->
          Mix.Tasks.JobyKit.Gen.Wrapper.run(["thing", "--category", "composite", "--daisy", "modal"])
        end
      end)
    end

    test "appends to existing composite_components.ex without recreating it",
         %{tmp_dir: tmp_dir} do
      in_installed_project(tmp_dir, fn ->
        Mix.Tasks.JobyKit.Gen.Wrapper.run(["one", "--category", "composite"])
        Mix.Tasks.JobyKit.Gen.Wrapper.run(["two", "--category", "composite"])

        comp = File.read!("lib/demo_app_web/components/composite_components.ex")
        assert comp =~ "def one(assigns)"
        assert comp =~ "def two(assigns)"
      end)
    end
  end

  describe "manifest entry placement" do
    test "inserts before def daisy_overrides", %{tmp_dir: tmp_dir} do
      in_installed_project(tmp_dir, fn ->
        Mix.Tasks.JobyKit.Gen.Wrapper.run(["metric_tile"])

        manifest = File.read!("lib/demo_app_web/design_manifest.ex")
        modal_pos = :binary.match(manifest, "component(DemoAppWeb.CoreComponents, :metric_tile,") |> elem(0)
        overrides_pos = :binary.match(manifest, "def daisy_overrides do") |> elem(0)
        assert modal_pos < overrides_pos
      end)
    end
  end

  describe "duplicate detection" do
    test "refuses to overwrite an existing function", %{tmp_dir: tmp_dir} do
      in_installed_project(tmp_dir, fn ->
        Mix.Tasks.JobyKit.Gen.Wrapper.run(["metric_tile"])

        assert_raise Mix.Error, ~r/function metric_tile\/1 already exists/, fn ->
          Mix.Tasks.JobyKit.Gen.Wrapper.run(["metric_tile"])
        end
      end)
    end

    test "refuses to overwrite an existing manifest entry even if file edits diverged",
         %{tmp_dir: tmp_dir} do
      in_installed_project(tmp_dir, fn ->
        # Pre-seed the manifest with a modal entry but no function in core.
        File.write!(
          "lib/demo_app_web/design_manifest.ex",
          File.read!("lib/demo_app_web/design_manifest.ex")
          |> String.replace(
            "  # ---------------------------------------------------------------------- core",
            "  component(CoreComponents, :metric_tile, category: :core, summary: \"x\", preview: &DesignPreviews.metric_tile_preview/1)\n\n  # ---------------------------------------------------------------------- core"
          )
        )

        assert_raise Mix.Error, ~r/manifest entry for CoreComponents.metric_tile already exists/, fn ->
          Mix.Tasks.JobyKit.Gen.Wrapper.run(["metric_tile"])
        end
      end)
    end
  end

  describe "input validation" do
    test "rejects non-snake_case names", %{tmp_dir: tmp_dir} do
      in_installed_project(tmp_dir, fn ->
        assert_raise Mix.Error, ~r/name must be snake_case/, fn ->
          Mix.Tasks.JobyKit.Gen.Wrapper.run(["ChatPanel"])
        end
      end)
    end

    test "rejects unknown --category", %{tmp_dir: tmp_dir} do
      in_installed_project(tmp_dir, fn ->
        assert_raise Mix.Error, ~r/unknown --category "domain"/, fn ->
          Mix.Tasks.JobyKit.Gen.Wrapper.run(["thing", "--category", "domain"])
        end
      end)
    end

    test "rejects missing name", %{tmp_dir: tmp_dir} do
      in_installed_project(tmp_dir, fn ->
        assert_raise Mix.Error, ~r/component name is required/, fn ->
          Mix.Tasks.JobyKit.Gen.Wrapper.run([])
        end
      end)
    end
  end

  test "scaffolded output parses, for both a core wrapper and a composite",
       %{tmp_dir: tmp_dir} do
    # The task's own stated success criterion is that `mix joby_kit.lint`
    # comes back clean afterwards; nothing verified even that the code it
    # inserts is syntactically valid. Insertion is done by regex against
    # the module's closing `end`, so a mismatch corrupts the file.
    in_installed_project(tmp_dir, fn ->
      Mix.Tasks.JobyKit.Gen.Wrapper.run(["metric_tile", "--daisy", "modal"])
      Mix.Tasks.JobyKit.Gen.Wrapper.run(["chat_panel", "--category", "composite"])

      for path <- Path.wildcard("lib/demo_app_web/**/*.ex") do
        case path |> File.read!() |> Code.string_to_quoted() do
          {:ok, _ast} -> :ok
          {:error, {meta, msg, token}} -> flunk("#{path} does not parse (#{inspect(meta)}): #{msg}#{token}")
        end
      end

      # And the generated wrapper still satisfies the contract it exists
      # to scaffold.
      composite = File.read!("lib/demo_app_web/components/composite_components.ex")
      assert composite =~ ~s|data-component="DemoAppWeb.CompositeComponents.chat_panel"|
      assert composite =~ "attr :rest, :global"
    end)
  end

  # ----------------------------------------------------------------- helpers

  defp in_installed_project(tmp_dir, fun) do
    project = Path.join(tmp_dir, "demo_app")
    File.mkdir_p!(project)

    Mix.Project.in_project(:demo_app, project, [], fn _ ->
      File.cd!(project, fn ->
        Mix.Tasks.JobyKit.Install.run([])
        seed_core_components()
        fun.()
      end)
    end)
  end

  defp seed_core_components do
    File.mkdir_p!("lib/demo_app_web/components")

    File.write!("lib/demo_app_web/components/core_components.ex", """
    defmodule DemoAppWeb.CoreComponents do
      @moduledoc \"\"\"
      Core wrappers for the demo app.
      \"\"\"

      use Phoenix.Component

      attr :rest, :global
      slot :inner_block, required: true

      def button(assigns) do
        ~H\"\"\"
        <button data-component="DemoAppWeb.CoreComponents.button" {@rest}>
          {render_slot(@inner_block)}
        </button>
        \"\"\"
      end
    end
    """)
  end
end
