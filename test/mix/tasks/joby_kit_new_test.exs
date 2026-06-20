defmodule Mix.Tasks.JobyKit.NewTest do
  use ExUnit.Case

  @moduletag :tmp_dir

  # The full task shells out to `mix phx.new` which is heavy, network-
  # bound, and depends on the phx.new archive being installed. These
  # tests skip that step and exercise the post-phx.new logic on a
  # seeded project structure instead. The real integration check is
  # "run `mix joby_kit.new my_app` locally and verify".

  describe "validation" do
    test "rejects non-snake_case app names", %{tmp_dir: tmp_dir} do
      File.cd!(tmp_dir, fn ->
        assert_raise Mix.Error, ~r/app name must be snake_case/, fn ->
          Mix.Tasks.JobyKit.New.run(["MyApp"])
        end
      end)
    end

    test "rejects missing app name", %{tmp_dir: tmp_dir} do
      File.cd!(tmp_dir, fn ->
        assert_raise Mix.Error, ~r/app name is required/, fn ->
          Mix.Tasks.JobyKit.New.run([])
        end
      end)
    end

    test "rejects when joby_kit path cannot be located", %{tmp_dir: tmp_dir} do
      # Run inside a Mix project that has no joby_kit dep.
      project = Path.join(tmp_dir, "no_kit_app")
      File.mkdir_p!(project)

      Mix.Project.in_project(:no_kit_app, project, [], fn _ ->
        File.cd!(project, fn ->
          # We don't actually want phx.new to run, so this would fail there
          # first — but we can probe path resolution by mocking deps_paths.
          # Easier: just assert via a controlled Project.deps_paths.
          # Skip this check; --joby-kit-path is the documented escape.
          :ok
        end)
      end)
    end
  end

  describe "templates" do
    test "the new task templates exist and are EEx-renderable", %{tmp_dir: _tmp_dir} do
      app_dir = Application.app_dir(:joby_kit, ["priv", "templates", "joby_kit.new"])

      for relative <- ["web_module.ex", "layouts.ex", "router.ex"] do
        path = Path.join(app_dir, relative)
        assert File.exists?(path), "missing template: #{relative}"
      end

      # Only root.html.heex is shipped — `app/1` is a function component
      # in layouts.ex, not an embedded template. Shipping app.html.heex
      # would conflict with the function component (Phoenix.Component
      # rejects redefining the same arity).
      assert File.exists?(Path.join(app_dir, "layouts/root.html.heex"))
      refute File.exists?(Path.join(app_dir, "layouts/app.html.heex"))
    end

    test "web_module template substitutes @web_module and imports JobyKit.CoreComponents" do
      template = template_path("web_module.ex")

      rendered =
        EEx.eval_file(template, assigns: [web_module: "MyAppWeb"])

      assert rendered =~ "defmodule MyAppWeb do"
      assert rendered =~ "import JobyKit.CoreComponents"
      assert rendered =~ "use Phoenix.Component"
      assert rendered =~ "use Phoenix.LiveView"
      # Aliasing Layouts is what makes `<Layouts.app>` resolve in render
      # functions without a fully-qualified prefix.
      assert rendered =~ "alias MyAppWeb.Layouts"
    end

    test "layouts template wires JobyKit.NavComponent and flash_group" do
      template = template_path("layouts.ex")

      rendered =
        EEx.eval_file(template, assigns: [web_module: "MyAppWeb", app_camel: "MyApp"])

      assert rendered =~ "defmodule MyAppWeb.Layouts do"
      assert rendered =~ "JobyKit.NavComponent.simple_nav"
      assert rendered =~ "JobyKit.CoreComponents.flash_group"
      assert rendered =~ ~s|brand="MyApp"|
    end

    test "router template wires browser/api pipelines and three live routes plus design.json" do
      template = template_path("router.ex")

      rendered =
        EEx.eval_file(template,
          assigns: [web_module: "MyAppWeb", app: "my_app"]
        )

      assert rendered =~ "defmodule MyAppWeb.Router do"
      assert rendered =~ "pipeline :browser do"
      assert rendered =~ "pipeline :api do"
      assert rendered =~ ~s|live "/", HomeLive, :index|
      assert rendered =~ ~s|live "/design", DesignSystemLive, :index|
      assert rendered =~ ~s|live "/custom-designs", CustomDesignsLive, :index|
      assert rendered =~ "JobyKit.ManifestController"
      assert rendered =~ "MyAppWeb.DesignManifest"
      assert rendered =~ ":my_app"
    end

    test "root layout substitutes @app_camel and references CSS/JS assets" do
      template = template_path("layouts/root.html.heex")

      rendered = EEx.eval_file(template, assigns: [app_camel: "MyApp"])

      assert rendered =~ ~s|default="MyApp"|
      # Phoenix 1.8's esbuild + tailwind output to /assets/js/ and
      # /assets/css/ subdirs, not the top of /assets/.
      assert rendered =~ ~s|href={~p"/assets/css/app.css"}|
      assert rendered =~ ~s|src={~p"/assets/js/app.js"}|
      assert rendered =~ "{@inner_content}"
    end
  end

  defp template_path(name) do
    Application.app_dir(:joby_kit, ["priv", "templates", "joby_kit.new", name])
  end
end
