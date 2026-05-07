defmodule Mix.Tasks.JobyKit.New do
  @shortdoc "Bootstrap a fresh phx.new project as a JobyKit demo"

  @moduledoc """
  Bootstraps a freshly generated `mix phx.new` project as a JobyKit demo.

  Composes `mix joby_kit.install` (which generates the manifest, previews,
  and the two LiveViews) with three additional steps appropriate for a
  blank greenfield project:

    1. Replace the default Phoenix landing page route
       (`get "/", PageController, :home`) with `live "/",
       DesignSystemLive, :index` so the kit catalogue is the home page.
    2. Add the `/custom-designs` and `/design.json` routes (so you don't
       need to copy them from the install task's printed instructions).
    3. Optionally delete the now-unused `PageController` and
       `PageHTML` modules. Pass `--keep-page-controller` to leave them
       in place.

  This task is destructive — it edits `router.ex` and may delete files.
  Use `mix joby_kit.install` instead if you have an existing project with
  meaningful state at `/`.

  ## Usage

      mix joby_kit.new
      mix joby_kit.new --force                  # overwrite generated files
      mix joby_kit.new --keep-page-controller   # leave PageController in place
      mix joby_kit.new --web MyAppWeb           # specify web module name

  After this task completes:

      mix phx.server

  ...and visit `http://localhost:4000/` for the kit-curated catalogue.
  """

  use Mix.Task

  @switches [force: :boolean, web: :string, keep_page_controller: :boolean]

  @impl Mix.Task
  def run(args) do
    {opts, _argv, _invalid} = OptionParser.parse(args, switches: @switches)

    install_args =
      []
      |> append_flag("--force", opts[:force])
      |> append_flag("--web", opts[:web])

    Mix.Task.run("joby_kit.install", install_args)

    app = Keyword.fetch!(Mix.Project.config(), :app)
    web_module = web_module_name(opts[:web], app)
    web_path = Macro.underscore(web_module)

    rewire_router(web_module, web_path)
    delete_page_controller(web_path, opts[:keep_page_controller])
    print_summary(web_module)

    :ok
  end

  defp append_flag(args, _flag, nil), do: args
  defp append_flag(args, _flag, false), do: args
  defp append_flag(args, flag, true), do: args ++ [flag]
  defp append_flag(args, flag, value) when is_binary(value), do: args ++ [flag, value]

  defp web_module_name(nil, app), do: "#{Macro.camelize(to_string(app))}Web"
  defp web_module_name(override, _app), do: override

  defp rewire_router(web_module, web_path) do
    router = "lib/#{web_path}/router.ex"

    contents =
      case File.read(router) do
        {:ok, body} -> body
        {:error, _} ->
          Mix.shell().error("* could not read #{router}; routes were not auto-injected")
          throw(:no_router)
      end

    contents
    |> replace_home_route(web_module)
    |> ensure_custom_designs_route()
    |> ensure_json_route(web_module)
    |> write_router(router)
  catch
    :no_router -> :ok
  end

  defp replace_home_route(contents, _web_module) do
    case Regex.run(~r{(\s*)get\s+"/",\s+PageController,\s+:home}, contents) do
      [match, indent] ->
        Mix.shell().info([:green, "* update ", :reset, "router (replace home route with /design LiveView)"])

        replacement =
          [
            ~s|live "/", DesignSystemLive, :index|,
            ~s|live "/custom-designs", CustomDesignsLive, :index|
          ]
          |> Enum.map(&"#{indent}#{&1}")
          |> Enum.join("")

        String.replace(contents, match, replacement, global: false)

      _ ->
        Mix.shell().info(
          [:yellow, "* skip ", :reset, "router (could not find default home route to replace)"]
        )

        contents
    end
  end

  defp ensure_custom_designs_route(contents) do
    if String.contains?(contents, "CustomDesignsLive") do
      contents
    else
      Mix.shell().info(
        [:yellow, "* note ", :reset, "could not auto-add CustomDesignsLive route — add it manually"]
      )

      contents
    end
  end

  defp ensure_json_route(contents, web_module) do
    if String.contains?(contents, "JobyKit.ManifestController") do
      contents
    else
      Mix.shell().info([:green, "* update ", :reset, "router (add /design.json route)"])

      block = """

        scope "/" do
          pipe_through :api

          get "/design.json", JobyKit.ManifestController, :show,
            private: %{joby_kit_manifest: #{web_module}.DesignManifest}
        end
      """

      String.replace(contents, ~r{\nend\s*\z}, block <> "\nend\n", global: false)
    end
  end

  defp write_router(contents, path), do: File.write!(path, contents)

  defp delete_page_controller(_web_path, true) do
    Mix.shell().info([:yellow, "* skip ", :reset, "PageController (kept by --keep-page-controller)"])
  end

  defp delete_page_controller(web_path, _keep) do
    candidates = [
      "lib/#{web_path}/controllers/page_controller.ex",
      "lib/#{web_path}/controllers/page_html.ex",
      "lib/#{web_path}/controllers/page_html"
    ]

    Enum.each(candidates, fn path ->
      cond do
        File.dir?(path) ->
          File.rm_rf!(path)
          Mix.shell().info([:red, "* remove ", :reset, "#{path}/"])

        File.regular?(path) ->
          File.rm!(path)
          Mix.shell().info([:red, "* remove ", :reset, path])

        true ->
          :ok
      end
    end)
  end

  defp print_summary(web_module) do
    Mix.shell().info("""

    JobyKit greenfield bootstrap complete.

    Routes wired:
      live "/", #{web_module}.DesignSystemLive, :index
      live "/custom-designs", #{web_module}.CustomDesignsLive, :index
      get  "/design.json", JobyKit.ManifestController, :show

    Start the server and visit http://localhost:4000/

      mix phx.server
    """)
  end
end
