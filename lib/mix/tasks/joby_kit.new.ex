defmodule Mix.Tasks.JobyKit.New do
  @shortdoc "Create a new Phoenix app with JobyKit baked in from minute one"

  @moduledoc """
  Wraps `mix phx.new` and replaces Phoenix's default HTML scaffolding
  with the JobyKit HTML layer.

  Why we don't pass `--no-html`: that flag also removes the asset
  pipeline (esbuild, tailwind, watchers, `Plug.Static`), which we still
  need. We let Phoenix generate everything and then overwrite the few
  files the kit owns (`<app>_web.ex`, layouts, router, and the
  PageController/PageHTML modules that go away in favor of `HomeLive`).

  ## Usage

      mix joby_kit.new <app_name> [phx.new flags] [joby_kit flags]

  ## Running from anywhere (Mix archive install)

  Install the kit as a global Mix archive so the task works from any
  directory:

      mix archive.install hex joby_kit

  After that, from anywhere:

      mix joby_kit.new my_app

  The wrapper writes `{:joby_kit, "~> X.Y"}` into the new app's
  `mix.exs`. To use a local checkout (e.g. when developing the kit
  itself), pass `--joby-kit-path /path/to/joby_kit` to write a path
  dep instead.

  ## Phoenix flags forwarded

  Pass-through to `mix phx.new`: `--database`, `--binary-id`,
  `--module`, `--app`, `--no-ecto`, `--no-mailer`, `--no-dashboard`,
  `--no-gettext`, `--verbose`. The wrapper always forces `--no-install`
  (we add `:joby_kit` and run `mix deps.get` ourselves so the kit is in
  the dep list before the fetch).

  ## JobyKit-specific flags

    * `--joby-kit-path <path>` — absolute path to a local JobyKit
      checkout. Writes `{:joby_kit, path: "..."}` into the new app's
      mix.exs. Useful when developing the kit itself. Defaults to
      detecting from the calling project's `Mix.Project.deps_paths()`,
      then falls back to a hex dep if no local checkout is found.

  ## What the task does

    1. Shells out: `mix phx.new <app_name> [forwarded flags] --no-install`.
    2. Adds `{:joby_kit, ...}` to the new app's mix.exs (hex dep by
       default, path dep when `--joby-kit-path` is given).
    3. Runs `mix deps.get` inside the new app.
    4. Replaces the kit-owned HTML files:
        * `lib/<app>_web.ex` — JobyKit-flavored, imports `JobyKit.CoreComponents`.
        * `lib/<app>_web/components/layouts.ex` — uses `JobyKit.NavComponent.simple_nav`
          and `JobyKit.CoreComponents.flash_group`.
        * `lib/<app>_web/components/layouts/root.html.heex`.
    5. Deletes the now-redundant Phoenix scaffolding: `<app>_web/components/core_components.ex`,
       `<app>_web/controllers/page_controller.ex`, `<app>_web/controllers/page_html.ex`,
       and `<app>_web/controllers/page_html/`.
    6. Runs `mix joby_kit.install` (manifest, previews, design pages, AGENTS.md patches).
    7. Generates `HomeLive` and replaces `router.ex` with a JobyKit-wired version.
    8. Runs `mix assets.setup` and `mix assets.build` so `priv/static/assets/`
       is populated before the first `mix phx.server`.

  After this task completes:

      cd <app_name>
      mix phx.server

  Then visit `http://localhost:4000/`.
  """

  use Mix.Task

  @switches [
    joby_kit_path: :string,
    # Phoenix pass-through flags. --install / --no-install are
    # intentionally absent: we always force --no-install on phx.new and
    # run deps.get ourselves so :joby_kit is in the list before the
    # fetch.
    database: :string,
    binary_id: :boolean,
    module: :string,
    app: :string,
    no_ecto: :boolean,
    no_mailer: :boolean,
    no_dashboard: :boolean,
    no_gettext: :boolean,
    verbose: :boolean
  ]

  @impl Mix.Task
  def run(argv) do
    {opts, positional, _invalid} = OptionParser.parse(argv, switches: @switches)

    app_name = parse_app_name(positional)
    dep_spec = resolve_dep_spec(opts)

    shell_out_phx_new(app_name, opts)

    File.cd!(app_name, fn ->
      app_camel = Macro.camelize(app_name)
      web_module = opts[:module] || (app_camel <> "Web")
      web_path = Macro.underscore(web_module)

      # The templates have to mirror the phx.new flags we forwarded: a
      # router that imports Phoenix.LiveDashboard.Router in an app
      # generated with --no-dashboard does not compile.
      dashboard? = not Keyword.get(opts, :no_dashboard, false)
      mailer? = not Keyword.get(opts, :no_mailer, false)

      assigns = [
        app: app_name,
        app_camel: app_camel,
        web_module: web_module,
        web_path: web_path,
        web_module_anchor: String.replace(web_path, "/", ""),
        dashboard?: dashboard?,
        mailer?: mailer?,
        dev_routes?: dashboard? or mailer?,
        gettext?: not Keyword.get(opts, :no_gettext, false)
      ]

      add_joby_kit_dep(dep_spec)
      run_subcmd("mix", ["deps.get"])

      generate_html_layer(assigns)
      delete_redundant_phoenix_scaffolding(assigns)

      Mix.Tasks.JobyKit.Install.run(["--web", web_module])

      # Path-dep mode only: rewrite the @source line in app.css to the
      # absolute kit path. For hex deps the install task's default
      # `@source "../../deps/joby_kit/lib"` resolves correctly because
      # Mix unpacks hex deps into deps/joby_kit/.
      case dep_spec do
        {:path, joby_kit_path} -> patch_app_css_for_path_dep(joby_kit_path)
        :hex -> :ok
      end

      generate_home_live(assigns)
      replace_router(assigns)

      # Install and build assets so `mix phx.server` works immediately
      # without a separate `mix setup`. Without this, the first request
      # 404s on /assets/app.css (the watchers haven't compiled yet).
      run_subcmd("mix", ["assets.setup"])
      run_subcmd("mix", ["assets.build"])

      print_summary(app_name, opts)
    end)
  end

  # -------------------------------------------------------- input parsing

  defp parse_app_name([app_name | _]) when is_binary(app_name) do
    if Regex.match?(~r/^[a-z][a-z0-9_]*$/, app_name) do
      app_name
    else
      Mix.raise(
        "app name must be snake_case (lowercase, digits, underscores). Got: #{inspect(app_name)}"
      )
    end
  end

  defp parse_app_name(_),
    do: Mix.raise("app name is required. Usage: mix joby_kit.new <app_name>")

  defp resolve_dep_spec(opts) do
    cond do
      opts[:joby_kit_path] ->
        {:path, Path.expand(opts[:joby_kit_path])}

      path = local_joby_kit_path() ->
        {:path, Path.expand(path)}

      true ->
        :hex
    end
  end

  defp local_joby_kit_path do
    # Mix.Project.deps_paths() raises when there's no surrounding Mix
    # project (e.g. running from an installed archive). Catch and fall
    # back to nil so the resolver returns :hex.
    try do
      Mix.Project.deps_paths() |> Map.get(:joby_kit)
    rescue
      _ -> nil
    end
  end

  # ----------------------------------------------------------- phx.new

  defp shell_out_phx_new(app_name, opts) do
    # We let Phoenix generate everything (including HTML scaffolding
    # and the asset pipeline) and overwrite/delete the kit-owned files
    # afterward. `--no-html` would also strip esbuild/tailwind/Plug.Static
    # which we need to keep. Forcing `--no-install` so :joby_kit ends up
    # in the dep list before deps.get runs.
    args = ["phx.new", app_name, "--no-install"] ++ phx_pass_through(opts)
    cmd = "mix " <> Enum.join(args, " ")
    Mix.shell().info([:cyan, "* running ", :reset, cmd])

    # Use Mix.shell().cmd/1 so the subprocess inherits the user's TTY.
    case Mix.shell().cmd(cmd) do
      0 -> :ok
      code -> Mix.raise("mix phx.new failed with exit code #{code}")
    end
  end

  defp phx_pass_through(opts) do
    flag = fn key, type ->
      case {Keyword.get(opts, key), type} do
        {nil, _} -> []
        {true, :boolean} -> ["--#{kebab(key)}"]
        {false, :boolean} -> []
        {value, :string} when is_binary(value) -> ["--#{kebab(key)}", value]
      end
    end

    # Note: --install and --no-install are intentionally NOT forwarded.
    # We always pass --no-install to phx.new and run deps.get ourselves.
    [
      flag.(:database, :string),
      flag.(:binary_id, :boolean),
      flag.(:module, :string),
      flag.(:app, :string),
      flag.(:no_ecto, :boolean),
      flag.(:no_mailer, :boolean),
      flag.(:no_dashboard, :boolean),
      flag.(:no_gettext, :boolean),
      flag.(:verbose, :boolean)
    ]
    |> List.flatten()
  end

  defp kebab(key), do: key |> Atom.to_string() |> String.replace("_", "-")

  # --------------------------------------------------- post-phx.new steps

  defp add_joby_kit_dep(dep_spec) do
    path = "mix.exs"
    source = File.read!(path)

    if String.contains?(source, ":joby_kit") do
      :ok
    else
      {dep_line, summary} = dep_line_and_summary(dep_spec)

      patched =
        Regex.replace(
          ~r/(defp deps do\s*\n\s*\[\s*\n)/,
          source,
          "\\1      #{dep_line}\n",
          global: false
        )

      # Regex.replace/4 returns the source unchanged when nothing matched,
      # so without this check a phx.new layout we don't recognise would
      # report success and then fail much later with an unrelated-looking
      # compile error about undefined JobyKit modules.
      unless String.contains?(patched, ":joby_kit") do
        Mix.raise("""
        could not add :joby_kit to #{Path.expand(path)}.

        The generated mix.exs doesn't have the `defp deps do [` shape this
        task patches — Phoenix may have changed its template. Add the dep
        by hand and re-run `mix joby_kit.install`:

            #{dep_line}
        """)
      end

      File.write!(path, patched)
      Mix.shell().info([:green, "* updating ", :reset, "mix.exs (added :joby_kit #{summary})"])
    end
  end

  defp dep_line_and_summary({:path, joby_kit_path}),
    do: {~s|{:joby_kit, path: "#{joby_kit_path}"},|, "path dep"}

  defp dep_line_and_summary(:hex),
    do: {~s|{:joby_kit, "~> #{kit_version()}"},|, "hex dep ~> #{kit_version()}"}

  defp kit_version do
    # Read the kit's own version from its application spec. Fallback to
    # a known-stable major if loading fails for any reason.
    case Application.spec(:joby_kit, :vsn) do
      nil -> "0.1"
      vsn -> vsn |> to_string() |> minor_version()
    end
  end

  defp minor_version(version_string) do
    case String.split(version_string, ".") do
      [major, minor | _] -> "#{major}.#{minor}"
      _ -> "0.1"
    end
  end

  defp run_subcmd(cmd, args) do
    full = "#{cmd} #{Enum.join(args, " ")}"
    Mix.shell().info([:cyan, "* running ", :reset, full])

    # Use Mix.shell().cmd/1 so prompts (e.g. first-time hex/rebar
    # install) reach the user's TTY instead of hanging silently.
    case Mix.shell().cmd(full) do
      0 -> :ok
      code -> Mix.raise("#{full} failed with exit code #{code}")
    end
  end

  defp generate_html_layer(assigns) do
    web_path = assigns[:web_path]

    File.mkdir_p!("lib/#{web_path}/components/layouts")

    copy_template("web_module.ex", "lib/#{web_path}.ex", assigns)
    copy_template("layouts.ex", "lib/#{web_path}/components/layouts.ex", assigns)
    copy_template("layouts/root.html.heex", "lib/#{web_path}/components/layouts/root.html.heex", assigns)
  end

  defp patch_app_css_for_path_dep(joby_kit_path) do
    path = "assets/css/app.css"
    source = File.read!(path)
    absolute_source_line = ~s|@source "#{joby_kit_path}/lib";|

    cond do
      String.contains?(source, absolute_source_line) ->
        :ok

      String.contains?(source, ~s|@source "../../deps/joby_kit/lib";|) ->
        patched =
          String.replace(
            source,
            ~s|@source "../../deps/joby_kit/lib";|,
            absolute_source_line
          )

        File.write!(path, patched)

        Mix.shell().info([
          :green,
          "* updating ",
          :reset,
          "#{path} (rewrote @source to absolute kit path for path-dep mode)"
        ])

      true ->
        # Install hadn't patched (unusual). Add the absolute line directly.
        Mix.shell().error(
          "could not find the JobyKit @source line in #{path}; please add `#{absolute_source_line}` manually."
        )
    end
  end

  defp delete_redundant_phoenix_scaffolding(assigns) do
    web_path = assigns[:web_path]

    # core_components.ex — kit owns these now via JobyKit.CoreComponents.
    # The host's :html macro imports the kit module, not this file.
    File.rm("lib/#{web_path}/components/core_components.ex")

    # PageController + PageHTML — replaced by HomeLive at "/".
    File.rm("lib/#{web_path}/controllers/page_controller.ex")
    File.rm("lib/#{web_path}/controllers/page_html.ex")
    File.rm_rf!("lib/#{web_path}/controllers/page_html")

    # Test files for the deleted modules.
    File.rm("test/#{web_path}/controllers/page_controller_test.exs")

    Mix.shell().info([
      :red,
      "* removing ",
      :reset,
      "Phoenix scaffolding superseded by JobyKit (core_components, page_controller, page_html)"
    ])
  end

  defp generate_home_live(assigns) do
    web_path = assigns[:web_path]
    template = template_path("home_live.ex")
    dest = "lib/#{web_path}/live/home_live.ex"
    File.mkdir_p!(Path.dirname(dest))
    Mix.Generator.copy_template(template, dest, assigns, force: true)
  end

  defp replace_router(assigns) do
    web_path = assigns[:web_path]
    copy_template("router.ex", "lib/#{web_path}/router.ex", assigns)
  end

  defp copy_template(name, dest, assigns) do
    Mix.Generator.copy_template(template_path(name), dest, assigns, force: true)
  end

  defp template_path(name) do
    Application.app_dir(:joby_kit, ["priv", "templates", "joby_kit.new", name])
  end

  # ------------------------------------------------------------ summary

  defp print_summary(app_name, opts) do
    db_step =
      if Keyword.get(opts, :no_ecto, false) do
        ""
      else
        """
            mix ecto.setup       # creates the dev DB and runs migrations
        """
      end

    Mix.shell().info("""

    JobyKit app generated.

    Next:

        cd #{app_name}
    #{String.trim_trailing(db_step, "\n")}
        mix phx.server

    Then visit http://localhost:4000/.

    ── For the AI agent picking up this app ──────────────────────────

    Two files at the project root are loaded automatically by your
    coding agent — read them before any UI work:

      • CLAUDE.md  — the wrapper-contract diagnostics (auto-loaded by
        Claude Code)
      • AGENTS.md  — the full JobyKit guidelines, build order, and rationale

    Then consume these in order:

      1. curl http://localhost:4000/design.json
         (component manifest — what's already registered)
      2. Open http://localhost:4000/design
         (kit-curated wrappers: <.button>, <.input>, <.icon>, <.card>, …)
      3. Open http://localhost:4000/custom-designs
         (this app's composites — see <.empty_state> for a worked example)

    After writing UI:

        mix joby_kit.lint    # verifies the wrapper contract end-to-end

    ── Symptoms you skipped step 1 ───────────────────────────────────

    If any of these are true after writing UI, you bypassed the wrapper
    contract — stop and lift the offending markup into a wrapper:

      • You wrote `<button class="…">`/`<input>`/`<textarea>` in `.heex`
        when `<.button>`/`<.input>` exists.
      • You styled a private function component as if it were a primitive.
      • You added a new component without `data-component`, without
        `attr :rest, :global`, or without a `DesignManifest` entry.

    `mix joby_kit.lint` will catch all three. Run it before claiming done.
    """)
  end
end
