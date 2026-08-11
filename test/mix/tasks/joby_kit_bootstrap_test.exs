defmodule Mix.Tasks.JobyKit.BootstrapTest do
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

      Mix.Tasks.JobyKit.Bootstrap.run([])

      router = File.read!("lib/demo_app_web/router.ex")
      refute router =~ ~s|get "/", PageController, :home|
      assert router =~ ~s|live "/", HomeLive, :index|
      assert router =~ ~s|live "/design", DesignSystemLive, :index|
      assert router =~ ~s|live "/custom-designs", CustomDesignsLive, :index|
      assert router =~ "JobyKit.ManifestController"

      home = File.read!("lib/demo_app_web/live/home_live.ex")
      assert home =~ "defmodule DemoAppWeb.HomeLive do"
      assert home =~ "Welcome to DemoApp."
      # Pages compose the host's <Layouts.app> instead of rendering
      # their own nav. Bootstrap doesn't add a duplicate nav.
      refute home =~ "JobyKit.NavComponent.simple_nav"

      design = File.read!("lib/demo_app_web/live/design_system_live.ex")
      assert design =~ "JobyKit.PageComponent.page_component"
      refute design =~ "JobyKit.NavComponent.simple_nav"

      custom = File.read!("lib/demo_app_web/live/custom_designs_live.ex")
      assert custom =~ "JobyKit.PageComponent.custom_page_component"
      refute custom =~ "JobyKit.NavComponent.simple_nav"

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

      Mix.Tasks.JobyKit.Bootstrap.run(["--keep-page-controller"])

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

      Mix.Tasks.JobyKit.Bootstrap.run([])
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

      Mix.Tasks.JobyKit.Bootstrap.run([])
      router_first = File.read!("lib/demo_app_web/router.ex")

      Mix.Tasks.JobyKit.Bootstrap.run(["--keep-page-controller", "--force"])
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

  test "patches the host's app.html.heex nav with kit links",
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
      File.mkdir_p!("lib/demo_app_web/components/layouts")

      File.write!("lib/demo_app_web/components/layouts/app.html.heex", """
      <header class="navbar">
        <div class="flex-none">
          <ul class="flex gap-4">
            <li><a href="/about">About</a></li>
          </ul>
        </div>
      </header>
      """)

      Mix.Tasks.JobyKit.Bootstrap.run([])

      contents = File.read!("lib/demo_app_web/components/layouts/app.html.heex")
      assert contents =~ "<%!-- jobykit:nav-start --%>"
      assert contents =~ ~s|<.link navigate={~p"/design"}>Design</.link>|
      assert contents =~ ~s|<.link navigate={~p"/custom-designs"}>Custom Designs</.link>|
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

  test "every generated and rewritten file is syntactically valid Elixir", %{tmp_dir: tmp_dir} do
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
      Mix.Tasks.JobyKit.Bootstrap.run([])

      # The router is rewritten by regex, so it is the likeliest thing to
      # end up unparseable — and nothing checked.
      for path <- Path.wildcard("lib/demo_app_web/**/*.ex") do
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
