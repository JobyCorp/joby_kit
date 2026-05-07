defmodule Mix.Tasks.JobyKit.NewTest do
  use ExUnit.Case

  @moduletag :tmp_dir

  test "generates HomeLive + nav-bearing design pages, rewires router with three live routes",
       %{tmp_dir: tmp_dir} do
    in_tmp_project(tmp_dir, "demo_app", fn ->
      seed_router("""
      defmodule DemoAppWeb.Router do
        use DemoAppWeb, :router

        pipeline :browser do
          plug :accepts, ["html"]
        end

        pipeline :api do
          plug :accepts, ["json"]
        end

        scope "/", DemoAppWeb do
          pipe_through :browser

          get "/", PageController, :home
        end
      end
      """)

      seed_page_controller()

      Mix.Tasks.JobyKit.New.run([])

      router = File.read!("lib/demo_app_web/router.ex")
      refute router =~ ~s|get "/", PageController, :home|
      assert router =~ ~s|live "/", HomeLive, :index|
      assert router =~ ~s|live "/design", DesignSystemLive, :index|
      assert router =~ ~s|live "/custom-designs", CustomDesignsLive, :index|
      assert router =~ "JobyKit.ManifestController"

      home = File.read!("lib/demo_app_web/live/home_live.ex")
      assert home =~ "defmodule DemoAppWeb.HomeLive do"
      assert home =~ ~s|JobyKit.NavComponent.simple_nav active="home"|
      assert home =~ "Welcome to DemoApp."

      design = File.read!("lib/demo_app_web/live/design_system_live.ex")
      assert design =~ ~s|JobyKit.NavComponent.simple_nav active="design"|
      assert design =~ "JobyKit.PageComponent.page_component"

      custom = File.read!("lib/demo_app_web/live/custom_designs_live.ex")
      assert custom =~ ~s|JobyKit.NavComponent.simple_nav active="custom-designs"|
      assert custom =~ "JobyKit.PageComponent.custom_page_component"

      refute File.exists?("lib/demo_app_web/controllers/page_controller.ex")
      refute File.exists?("lib/demo_app_web/controllers/page_html.ex")
      refute File.dir?("lib/demo_app_web/controllers/page_html")

      assert File.exists?("lib/demo_app_web/design_manifest.ex")
    end)
  end

  test "--keep-page-controller leaves the controller files in place",
       %{tmp_dir: tmp_dir} do
    in_tmp_project(tmp_dir, "demo_app", fn ->
      seed_router("""
      defmodule DemoAppWeb.Router do
        use DemoAppWeb, :router

        pipeline :browser, do: plug(:accepts, ["html"])
        pipeline :api, do: plug(:accepts, ["json"])

        scope "/", DemoAppWeb do
          pipe_through :browser
          get "/", PageController, :home
        end
      end
      """)

      seed_page_controller()

      Mix.Tasks.JobyKit.New.run(["--keep-page-controller"])

      assert File.exists?("lib/demo_app_web/controllers/page_controller.ex")
      assert File.exists?("lib/demo_app_web/controllers/page_html.ex")
    end)
  end

  test "removes pre-existing /design and /custom-designs live routes before re-adding them",
       %{tmp_dir: tmp_dir} do
    in_tmp_project(tmp_dir, "demo_app", fn ->
      # Simulate the state of a host that has previously run
      # mix joby_kit.install and added the routes manually.
      seed_router("""
      defmodule DemoAppWeb.Router do
        use DemoAppWeb, :router

        pipeline :browser, do: plug(:accepts, ["html"])
        pipeline :api, do: plug(:accepts, ["json"])

        scope "/", DemoAppWeb do
          pipe_through :browser
          get "/", PageController, :home
          live "/design", DesignSystemLive, :index
          live "/custom-designs", CustomDesignsLive, :index
        end
      end
      """)

      seed_page_controller()

      Mix.Tasks.JobyKit.New.run([])
      router = File.read!("lib/demo_app_web/router.ex")

      # Each route should appear exactly once after the dedupe + replace.
      for fragment <- [
            ~s|live "/", HomeLive, :index|,
            ~s|live "/design", DesignSystemLive, :index|,
            ~s|live "/custom-designs", CustomDesignsLive, :index|
          ] do
        assert length(String.split(router, fragment)) == 2,
               "expected #{fragment} once, got: #{router}"
      end
    end)
  end

  test "is idempotent: running twice does not duplicate the JSON scope or live routes",
       %{tmp_dir: tmp_dir} do
    in_tmp_project(tmp_dir, "demo_app", fn ->
      seed_router("""
      defmodule DemoAppWeb.Router do
        use DemoAppWeb, :router

        pipeline :browser, do: plug(:accepts, ["html"])
        pipeline :api, do: plug(:accepts, ["json"])

        scope "/", DemoAppWeb do
          pipe_through :browser
          get "/", PageController, :home
        end
      end
      """)

      seed_page_controller()

      Mix.Tasks.JobyKit.New.run([])
      router_first = File.read!("lib/demo_app_web/router.ex")

      Mix.Tasks.JobyKit.New.run(["--keep-page-controller", "--force"])
      router_second = File.read!("lib/demo_app_web/router.ex")

      # JSON route appears once.
      [_, _] = String.split(router_first, "JobyKit.ManifestController")
      [_, _] = String.split(router_second, "JobyKit.ManifestController")

      # Each kit live route appears exactly once.
      for fragment <- [
            ~s|live "/", HomeLive, :index|,
            ~s|live "/design", DesignSystemLive, :index|,
            ~s|live "/custom-designs", CustomDesignsLive, :index|
          ] do
        assert length(String.split(router_second, fragment)) == 2,
               "expected #{fragment} once, got: #{router_second}"
      end
    end)
  end

  defp seed_router(contents) do
    File.mkdir_p!("lib/demo_app_web")
    File.write!("lib/demo_app_web/router.ex", contents)
  end

  defp seed_page_controller do
    File.mkdir_p!("lib/demo_app_web/controllers/page_html")
    File.write!("lib/demo_app_web/controllers/page_controller.ex", "defmodule X do; end\n")
    File.write!("lib/demo_app_web/controllers/page_html.ex", "defmodule X do; end\n")
    File.write!("lib/demo_app_web/controllers/page_html/home.html.heex", "<h1>home</h1>\n")
  end

  defp in_tmp_project(tmp_dir, app_name, fun) do
    project = Path.join(tmp_dir, app_name)
    File.mkdir_p!(project)

    Mix.Project.in_project(String.to_atom(app_name), project, [], fn _ ->
      File.cd!(project, fun)
    end)
  end
end
