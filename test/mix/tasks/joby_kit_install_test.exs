defmodule Mix.Tasks.JobyKit.InstallTest do
  use ExUnit.Case

  @moduletag :tmp_dir

  test "generates the four expected files using the host's app + web module names",
       %{tmp_dir: tmp_dir} do
    in_tmp_project(tmp_dir, "demo_app", fn ->
      Mix.Tasks.JobyKit.Install.run([])

      manifest = File.read!("lib/demo_app_web/design_manifest.ex")
      assert manifest =~ "defmodule DemoAppWeb.DesignManifest do"
      assert manifest =~ "use JobyKit.Manifest"
      assert manifest =~ "alias JobyKit.CoreComponents"
      assert manifest =~ "alias DemoAppWeb.DesignPreviews"

      # The kit ships scaffolding pre-registered against JobyKit.CoreComponents.
      # All nine, not just the obvious five: header/list/table/flash_group were
      # shipped-but-unregistered through 0.2.2, so agents following the build
      # order couldn't discover half the kit.
      for name <- ~w(button card icon input flash flash_group header list table theme_toggle) do
        assert manifest =~ "component CoreComponents, :#{name},",
               "expected #{name} to be registered in the generated manifest"
      end

      # daisy_overrides points at the kit's anchors, not the host's, and
      # reports every primitive the kit actually wraps.
      assert manifest =~ ~s|"#jobykit-component-jobykit-corecomponents-button"|
      assert manifest =~ ~s|"#jobykit-component-jobykit-corecomponents-card"|
      assert manifest =~ ~s|"#jobykit-component-jobykit-corecomponents-table"|
      assert manifest =~ ~s|"#jobykit-component-jobykit-corecomponents-flash_group"|
      # simple_nav lives in NavComponent, so it needs its own alias + anchor.
      assert manifest =~ "alias JobyKit.NavComponent"
      assert manifest =~ "component NavComponent, :simple_nav,"
      assert manifest =~ ~s|"#jobykit-component-jobykit-navcomponent-simple_nav"|

      # Every registered entry that declares a preview must have one defined,
      # or /design 500s on the missing function.
      previews_src = File.read!("lib/demo_app_web/design_previews.ex")

      for [_, fun] <- Regex.scan(~r/preview: &DesignPreviews\.(\w+)\/1/, manifest) do
        assert previews_src =~ "def #{fun}(assigns)",
               "manifest references DesignPreviews.#{fun}/1 but it is not defined"
      end

      previews = File.read!("lib/demo_app_web/design_previews.ex")
      assert previews =~ "defmodule DemoAppWeb.DesignPreviews do"
      assert previews =~ "use DemoAppWeb, :html"
      assert previews =~ "alias JobyKit.CoreComponents"
      assert previews =~ "def button_preview(assigns)"
      assert previews =~ "def card_preview(assigns)"
      assert previews =~ "def icon_preview(assigns)"
      assert previews =~ "def input_preview(assigns)"
      assert previews =~ "def flash_preview(assigns)"
      assert previews =~ "def header_preview(assigns)"
      assert previews =~ "def list_preview(assigns)"
      assert previews =~ "def table_preview(assigns)"
      assert previews =~ "def theme_toggle_preview(assigns)"
      assert previews =~ "def simple_nav_preview(assigns)"

      design_live = File.read!("lib/demo_app_web/live/design_system_live.ex")
      assert design_live =~ "defmodule DemoAppWeb.DesignSystemLive do"
      assert design_live =~ "JobyKit.PageComponent.page_component"
      assert design_live =~ "manifest={DemoAppWeb.DesignManifest}"

      custom_live = File.read!("lib/demo_app_web/live/custom_designs_live.ex")
      assert custom_live =~ "defmodule DemoAppWeb.CustomDesignsLive do"
      assert custom_live =~ "JobyKit.PageComponent.custom_page_component"

      # Worked composite example is scaffolded and registered.
      composite = File.read!("lib/demo_app_web/components/composite_components.ex")
      assert composite =~ "defmodule DemoAppWeb.CompositeComponents do"
      assert composite =~ "def empty_state(assigns)"
      assert composite =~ ~s|data-component="DemoAppWeb.CompositeComponents.empty_state"|

      assert manifest =~ "alias DemoAppWeb.CompositeComponents"
      assert manifest =~ "component CompositeComponents, :empty_state,"
      assert previews =~ "def empty_state_preview(assigns)"
    end)
  end

  test "creates CLAUDE.md with the wrapper-contract block", %{tmp_dir: tmp_dir} do
    in_tmp_project(tmp_dir, "demo_app", fn ->
      Mix.Tasks.JobyKit.Install.run([])

      contents = File.read!("CLAUDE.md")
      assert contents =~ "<!-- jobykit:start -->"
      assert contents =~ "Symptoms you skipped step 1"
      assert contents =~ "raw `<button>`"
      assert contents =~ "mix joby_kit.lint"
    end)
  end

  test "respects --web override", %{tmp_dir: tmp_dir} do
    in_tmp_project(tmp_dir, "underscore_app", fn ->
      Mix.Tasks.JobyKit.Install.run(["--web", "MyCustomWeb"])

      assert File.read!("lib/my_custom_web/design_manifest.ex") =~
               "defmodule MyCustomWeb.DesignManifest do"

      refute File.exists?("lib/underscore_app_web/design_manifest.ex")
    end)
  end

  test "skips existing files without --force", %{tmp_dir: tmp_dir} do
    in_tmp_project(tmp_dir, "demo_app", fn ->
      File.mkdir_p!("lib/demo_app_web/live")
      File.write!("lib/demo_app_web/design_manifest.ex", "# pre-existing\n")

      Mix.Tasks.JobyKit.Install.run([])

      # The existing file is preserved.
      assert File.read!("lib/demo_app_web/design_manifest.ex") == "# pre-existing\n"

      # Other files generate normally.
      assert File.exists?("lib/demo_app_web/design_previews.ex")
    end)
  end

  test "overwrites existing files when --force is passed", %{tmp_dir: tmp_dir} do
    in_tmp_project(tmp_dir, "demo_app", fn ->
      File.mkdir_p!("lib/demo_app_web/live")
      File.write!("lib/demo_app_web/design_manifest.ex", "# stale\n")

      Mix.Tasks.JobyKit.Install.run(["--force"])

      assert File.read!("lib/demo_app_web/design_manifest.ex") =~ "use JobyKit.Manifest"
    end)
  end

  test "patches assets/css/app.css with the joby_kit @source line", %{tmp_dir: tmp_dir} do
    in_tmp_project(tmp_dir, "demo_app", fn ->
      File.mkdir_p!("assets/css")

      File.write!("assets/css/app.css", """
      @import "tailwindcss" source(none);
      @source "../css";
      @source "../js";
      @source "../../lib/demo_app_web";
      """)

      Mix.Tasks.JobyKit.Install.run([])

      assert File.read!("assets/css/app.css") =~ ~s|@source "../../deps/joby_kit/lib";|
    end)
  end

  test "patches app.html.heex nav to add /design and /custom-designs links",
       %{tmp_dir: tmp_dir} do
    in_tmp_project(tmp_dir, "demo_app", fn ->
      File.mkdir_p!("lib/demo_app_web/components/layouts")

      File.write!("lib/demo_app_web/components/layouts/app.html.heex", """
      <header class="navbar">
        <div class="flex-none">
          <ul class="flex gap-4">
            <li><a href="/about">About</a></li>
          </ul>
        </div>
      </header>
      <main>{@inner_content}</main>
      """)

      Mix.Tasks.JobyKit.Install.run([])

      contents = File.read!("lib/demo_app_web/components/layouts/app.html.heex")
      assert contents =~ "<%!-- jobykit:nav-start --%>"
      assert contents =~ ~s|<.link navigate={~p"/design"}>Design</.link>|
      assert contents =~ ~s|<.link navigate={~p"/custom-designs"}>Custom Designs</.link>|
      # The existing <li> survived.
      assert contents =~ ~s|<li><a href="/about">About</a></li>|
    end)
  end

  test "falls back to layouts.ex when app.html.heex has no nav",
       %{tmp_dir: tmp_dir} do
    in_tmp_project(tmp_dir, "demo_app", fn ->
      File.mkdir_p!("lib/demo_app_web/components")

      File.write!("lib/demo_app_web/components/layouts.ex", """
      defmodule DemoAppWeb.Layouts do
        use DemoAppWeb, :html

        def app(assigns) do
          ~H\"\"\"
          <header>
            <ul>
              <li>Home</li>
            </ul>
          </header>
          <main>{render_slot(@inner_block)}</main>
          \"\"\"
        end
      end
      """)

      Mix.Tasks.JobyKit.Install.run([])

      contents = File.read!("lib/demo_app_web/components/layouts.ex")
      assert contents =~ "<%!-- jobykit:nav-start --%>"
      assert contents =~ ~s|<.link navigate={~p"/design"}>Design</.link>|
    end)
  end

  test "is idempotent — second install run leaves the nav block untouched",
       %{tmp_dir: tmp_dir} do
    in_tmp_project(tmp_dir, "demo_app", fn ->
      File.mkdir_p!("lib/demo_app_web/components/layouts")

      File.write!("lib/demo_app_web/components/layouts/app.html.heex", """
      <header>
        <ul>
          <li>Home</li>
        </ul>
      </header>
      """)

      Mix.Tasks.JobyKit.Install.run([])
      first = File.read!("lib/demo_app_web/components/layouts/app.html.heex")

      Mix.Tasks.JobyKit.Install.run([])
      second = File.read!("lib/demo_app_web/components/layouts/app.html.heex")

      # Second run must produce identical output — no duplicate insertion.
      assert first == second
      # And only one start marker.
      assert length(String.split(second, "<%!-- jobykit:nav-start --%>")) == 2
    end)
  end

  test "every generated file is syntactically valid Elixir", %{tmp_dir: tmp_dir} do
    # The suite asserts on generated *strings*; nothing ever parsed them, so
    # a HEEx syntax error or an unbalanced heredoc in a template would ship
    # green and only surface in a host app's compile.
    in_tmp_project(tmp_dir, "demo_app", fn ->
      Mix.Tasks.JobyKit.Install.run([])

      generated = Path.wildcard("lib/demo_app_web/**/*.ex")

      assert length(generated) == 5, "expected 5 generated files, got: #{inspect(generated)}"

      for path <- generated do
        case path |> File.read!() |> Code.string_to_quoted() do
          {:ok, _ast} ->
            :ok

          {:error, {meta, msg, token}} ->
            flunk("#{path} does not parse (#{inspect(meta)}): #{msg}#{token}")
        end
      end
    end)
  end

  defp in_tmp_project(tmp_dir, app_name, fun) do
    project = Path.join(tmp_dir, app_name)
    File.mkdir_p!(project)

    Mix.Project.in_project(String.to_atom(app_name), project, [], fn _ ->
      File.cd!(project, fun)
    end)
  end
end
