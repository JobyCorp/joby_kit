defmodule Mix.Tasks.JobyKit.Install do
  @shortdoc "Install JobyKit into an existing Phoenix application"

  @moduledoc """
  Installs JobyKit into an existing Phoenix project.

  Generates four files under `lib/<your_app>_web/`:

    * `design_manifest.ex` — `use JobyKit.Manifest` declaration with one
      example component registration and a `daisy_overrides/0` callback.
    * `design_previews.ex` — preview functions for the registered
      components (one per component, suffixed `_preview`).
    * `live/design_system_live.ex` — the kit-curated `/design` page.
    * `live/custom_designs_live.ex` — the host-owned `/custom-designs`
      page for composites and domain components.

  Existing files are not overwritten unless you pass `--force`. Routes
  are not auto-injected; the task prints the lines you need to add to
  `router.ex` at the end.

  ## Usage

      mix joby_kit.install
      mix joby_kit.install --force            # overwrite existing files
      mix joby_kit.install --web MyAppWeb     # specify web module name

  ## Next steps

  After running this task, follow the printed instructions to:

    1. Add the two `live` routes and the JSON `get` route to your
       `router.ex`.
    2. Restart the dev server.
    3. Visit `/design` and `/custom-designs`.

  See the `mix joby_kit.new` task for a more aggressive variant aimed at
  fresh `mix phx.new` projects (replaces the default Phoenix landing
  page).
  """

  use Mix.Task

  @switches [force: :boolean, web: :string]

  @impl Mix.Task
  def run(args) do
    {opts, _argv, _invalid} = OptionParser.parse(args, switches: @switches)

    app = Keyword.fetch!(Mix.Project.config(), :app)
    web_module = web_module_name(opts[:web], app)
    web_path = Macro.underscore(web_module)
    web_module_anchor = String.replace(web_path, "/", "")

    assigns = [
      app: app,
      web_module: web_module,
      web_path: web_path,
      web_module_anchor: web_module_anchor
    ]

    targets = [
      {"design_manifest.ex", "lib/#{web_path}/design_manifest.ex"},
      {"design_previews.ex", "lib/#{web_path}/design_previews.ex"},
      {"design_system_live.ex", "lib/#{web_path}/live/design_system_live.ex"},
      {"custom_designs_live.ex", "lib/#{web_path}/live/custom_designs_live.ex"}
    ]

    File.mkdir_p!("lib/#{web_path}/live")

    force? = opts[:force] == true

    Enum.each(targets, fn {template, dest} ->
      template_path = template_path(template)
      copy_or_skip(template_path, dest, assigns, force?)
    end)

    print_next_steps(web_module)
    :ok
  end

  defp web_module_name(nil, app) do
    "#{Macro.camelize(to_string(app))}Web"
  end

  defp web_module_name(override, _app) when is_binary(override), do: override

  defp template_path(name) do
    Application.app_dir(:joby_kit, ["priv", "templates", "joby_kit.install", name])
  end

  defp copy_or_skip(source, dest, assigns, force?) do
    if File.exists?(dest) and not force? do
      Mix.shell().info("* skip #{dest} (already exists; use --force to overwrite)")
    else
      Mix.Generator.copy_template(source, dest, assigns, force: true)
    end
  end

  defp print_next_steps(web_module) do
    Mix.shell().info("""

    JobyKit files generated.

    Add these routes to your router (lib/#{Macro.underscore(web_module)}/router.ex):

        scope "/", #{web_module} do
          pipe_through :browser

          live "/design", DesignSystemLive, :index
          live "/custom-designs", CustomDesignsLive, :index
        end

        scope "/" do
          # The JSON endpoint needs a JSON-accepting pipeline. Use the
          # default `:api` pipeline that ships with `mix phx.new`, or
          # roll your own that fetches sessions/auth if you want to
          # gate the manifest behind a logged-in user.
          pipe_through :api

          get "/design.json", JobyKit.ManifestController, :show,
            private: %{joby_kit_manifest: #{web_module}.DesignManifest}
        end

    Then restart `mix phx.server`, visit /design and /custom-designs, and
    extend lib/#{Macro.underscore(web_module)}/design_manifest.ex with
    your own component registrations.

    Tip: run `curl http://localhost:PORT/design.json | jq` to see the
    machine-readable manifest your AI agents can consume.
    """)
  end
end
