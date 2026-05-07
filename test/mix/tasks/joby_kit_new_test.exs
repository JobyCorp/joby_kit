defmodule Mix.Tasks.JobyKit.NewTest do
  use ExUnit.Case

  @moduletag :tmp_dir

  test "rewires the home route to DesignSystemLive and adds custom-designs + json routes",
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

      # Home route is replaced with the kit LiveView and the custom-designs
      # LiveView is added alongside it.
      refute router =~ ~s|get "/", PageController, :home|
      assert router =~ ~s|live "/", DesignSystemLive, :index|
      assert router =~ ~s|live "/custom-designs", CustomDesignsLive, :index|

      # JSON route inserted before the closing `end` of the module.
      assert router =~ "JobyKit.ManifestController"
      assert router =~ ~s|joby_kit_manifest: DemoAppWeb.DesignManifest|

      # PageController and PageHTML are deleted by default.
      refute File.exists?("lib/demo_app_web/controllers/page_controller.ex")
      refute File.exists?("lib/demo_app_web/controllers/page_html.ex")
      refute File.dir?("lib/demo_app_web/controllers/page_html")

      # The install templates ran (sanity check).
      assert File.exists?("lib/demo_app_web/design_manifest.ex")
      assert File.exists?("lib/demo_app_web/live/design_system_live.ex")
      assert File.exists?("lib/demo_app_web/live/custom_designs_live.ex")
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

  test "is idempotent: running twice does not duplicate the JSON scope or routes",
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
      router_after_first = File.read!("lib/demo_app_web/router.ex")

      Mix.Tasks.JobyKit.New.run(["--keep-page-controller", "--force"])
      router_after_second = File.read!("lib/demo_app_web/router.ex")

      # JSON route appears once, not twice.
      [_, _] = String.split(router_after_first, "JobyKit.ManifestController")
      [_, _] = String.split(router_after_second, "JobyKit.ManifestController")
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
