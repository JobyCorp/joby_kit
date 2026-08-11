# Changelog

## v0.2.3

Fixes a crash that takes down any form with an array-typed field, plus
two `CoreComponents` corrections and the missing half of the shipped
manifest.

* **`translate_error/1`: no longer raises on non-`String.Chars` error
  opts.** It stringified every opt eagerly instead of deferring to
  `String.replace/4`'s function form, so the opts Ecto attaches to a
  cast error on an `{:array, _}` field —
  `[type: {:array, :string}, validation: :cast]` — raised
  `Protocol.UndefinedError` on the tuple. Every `<.input field={...}>`
  routes errors through this, so the first invalid submit on any form
  with an array or composite-typed field returned a 500. Same class of
  crash for `validate_subset`/`validate_inclusion` opts carrying atom
  lists. If you worked around this by overriding `translate_error/1`,
  you can drop the override.
* **`button/1`: `type` now passes through.** It was neither a declared
  attr nor in the `:global` include list, so `<.button type="button">`
  emitted an "undefined attribute" warning and the attribute was
  dropped — every button inside a form submitted it, with no way to opt
  out. Omitting `type` still leaves the attribute off, so existing
  submit buttons are unaffected. `form` passes through too.
* **`flash/1` + `flash_group/1`: one toast container per page instead
  of one per notice.** Each `flash/1` rendered its own fixed-position
  `toast toast-top toast-end` container, so simultaneous notices — an
  `:info` and an `:error` from the same action, or a flash plus a
  disconnect toast — stacked at the identical fixed position and
  occluded each other. The `toast` container now lives on
  `flash_group/1` and every notice stacks inside it.
  **Behavior change:** `flash/1` rendered on its own is now an inline
  `alert` and no longer positions itself. If you call `flash/1` outside
  `flash_group/1` and relied on it floating, wrap it in your own
  positioned container. Calling `flash_group/1` from your root layout —
  the documented path — needs no change.
  The container is `pointer-events-none` (notices re-enable it), so the
  now-always-present fixed element can't intercept clicks in an empty
  corner. `:info` notices are `role="status"` rather than the
  interrupting `role="alert"`; errors stay assertive. Both components
  now declare `attr :class`, so a caller class merges into the root
  instead of colliding with the identity classes.
* **The install manifest registers all nine shipped wrappers.** It
  listed only `button`, `card`, `icon`, `input`, and `flash`, while the
  kit also ships `header`, `list`, `table`, and `flash_group` — shipped,
  documented, and invisible on `/design` and in `/design.json`, so
  agents following the build order re-wrapped or hand-rolled them.
  `daisy_overrides/0` likewise now reports every primitive the kit
  actually wraps (alert, toast, list, table, and the four input types)
  instead of just button and card. Existing apps: re-run
  `mix joby_kit.install --force` to pick up the new registrations, or
  copy the entries into your `DesignManifest` by hand.
  (`flash_group` is registered without a preview on purpose — it's a
  fixed-position container, so an inline preview would float over the
  design page rather than sit in its card.)

Note for hosts that **forked** a core component (`import
JobyKit.CoreComponents, except: [...]`): the `button/1` and `flash/1`
fixes above land in the kit's copy, not yours. Apply them to your fork.

## v0.2.2

Docs-only release. No functional change — skip it if 0.2.1 is working
for you.

* ExDoc no longer tries to link the internal patcher modules
  (`JobyKit.AgentsMd`, `JobyKit.ClaudeMd`, `JobyKit.NavPatcher`,
  `JobyKit.AppCss`), which are `@moduledoc false` on purpose, or
  `Phoenix.Component.__components__/0`, which is hidden upstream. They
  render as plain code via `skip_code_autolink_to`, so the published
  docs build warning-free.

## v0.2.1

Two rendering fixes, both in `CoreComponents`:

* `flash/1`: every toast gets a usable `id` again. `attr :id` already
  puts `:id` in assigns, so the `assign_new/3` default never fired and
  any flash rendered without an explicit id — both toasts
  `flash_group/1` shows, i.e. the ones users actually see — rendered
  with no `id` attribute and a dismiss handler of `JS.hide(to: "#")`.
  `#` is not a valid selector, so clicking a flash threw
  `Failed to execute 'querySelectorAll' on 'Document'` and the toast
  never faded out. The `lv:clear-flash` push runs first, so the flash
  still cleared — which is how this stayed hidden behind a
  working-looking dismiss.
* `table/1`: action cell gains `whitespace-nowrap`. Wrappable button
  text let the cell under-report min-content under the `w-0` width
  hack, so action buttons painted past the table edge on full-width
  tables. Host apps carrying a scoped nowrap override for
  `[data-component="JobyKit.CoreComponents.table"]` can drop it after
  upgrading.

## v0.2.0

Wrapper-contract enforcement: agent-experience fixes for the failure
mode where an agent skips the manifest, drops raw HTML primitives into
`.heex`, and gets a green lint check anyway. This release closes that
loop with a real lint rule, an auto-loaded `CLAUDE.md`, and a worked
composite example. Existing consumers may see new warnings on first
`mix joby_kit.lint` run after upgrading — that's the rule firing on
pre-existing violations; silence per-line with
`<%!-- jobykit:allow-raw-html --%>` or lift the markup into a wrapper.

### Linter

* New `:raw_html_primitive` rule (warning). Scans `.heex` and `~H`
  blocks in `.ex` for raw `<button>`, `<input>`, `<textarea>`, and
  `<select>` outside of wrapper definitions. Files containing
  `data-component=` are treated as wrapper territory and skipped.
  Per-line opt-out via `<%!-- jobykit:allow-raw-html --%>` (heex) or
  `# jobykit:allow-raw-html` on the preceding `.ex` line. Inside
  Elixir string literals (heuristically detected) doesn't fire.
* `mix joby_kit.lint` default `--paths` now includes `lib/**/*.heex`
  alongside `lib/**/*.ex`.

### CLAUDE.md

* `mix joby_kit.install` now writes a `CLAUDE.md` block at the project
  root (auto-loaded by Claude Code) that inlines the highest-priority
  wrapper-contract diagnostics — including "Symptoms you skipped step
  1" and the per-line opt-out syntax. Idempotent and marker-bracketed
  like `AGENTS.md`.
* New `JobyKit.ClaudeMd` patcher mirrors `JobyKit.AgentsMd`.

### Worked composite example

* `mix joby_kit.install` now scaffolds `<App>Web.CompositeComponents`
  with a working `empty_state/1` composite (icon + title + supporting
  text + optional action slot). Pre-registered in the generated
  `DesignManifest` and previewed on `/custom-designs`. Pattern-match on
  it when adding your own composites.

### Bootstrap stdout

* `mix joby_kit.new`, `mix joby_kit.install`, and `mix joby_kit.bootstrap`
  end-of-run summaries now inline the "Symptoms you skipped step 1"
  diagnostic (raw `<button>`/`<input>`, private function components
  styled as primitives, components missing `data-component`/`:rest`/
  manifest entry). Calling out the failure modes in stdout means an
  agent doesn't have to know to open `AGENTS.md` to find them.

## v0.1.1

Documentation + first-run UX fixes for hex consumers:

* `mix joby_kit.new` now defaults to a hex dep (`{:joby_kit, "~> X.Y"}`)
  when no `--joby-kit-path` is given. The flag stays for kit
  development; the README and moduledoc lead with the hex install path
  (`mix archive.install hex joby_kit`).
* `README.md` and `mix joby_kit.new` moduledoc rewritten to drop
  references to local checkouts and `.ez` build steps.
* `mix joby_kit.new` skips the path-dep `app.css` rewrite when running
  in hex mode (the install task's default `@source` already resolves
  for hex deps).

No runtime API changes.

## v0.1.0

Initial release. JobyKit ships:

### Manifest + design pages

* `JobyKit.Manifest` — behaviour + `__using__` macro for declaring a host
  component manifest. `category/2` and `component/3` macros register entries;
  `@before_compile` generates `entries/0`, `by_category/0`, `categories/0`,
  `category_label/1`, `category_description/1`, `fetch/2` callbacks. The
  runtime `enrich/1` helper introspects each component's attrs/slots via
  `Phoenix.Component.__components__/0` so prop signatures never drift from
  source.

* `JobyKit.Contract` — universal contract content (5-step build order,
  5-rule wrapper checklist, 3-layer module taxonomy) as plain data.

* `JobyKit.DaisyCatalogue` — canonical list of every daisyUI primitive
  (62 entries across 7 daisy categories), with stable atom IDs, default
  statuses, a `merged/1` overlay that applies host overrides, and a
  `demo/1` function component dispatched per primitive.

* `JobyKit.SignatureComponent` — per-component signature card renderer.

* `JobyKit.PageComponent` — two function components for the design surfaces:
  * `page_component/1` — the kit's curated `/design` page (filters to
    `:core` only). Optional `:custom_path` attr renders an
    agent-redirect callout pointing new components to the host's
    custom-designs page.
  * `custom_page_component/1` — host's `/custom-designs` page (renders
    only non-`:core` entries) with a breadcrumb back to the kit page.

* `JobyKit.ManifestController` — JSON endpoint serving the *combined*
  manifest (kit core + composites + domain) at `/design.json`. Reads the
  manifest module from `conn.private[:joby_kit_manifest]`.

### Core components

* `JobyKit.CoreComponents` — kit-shipped wrappers that hosts import: 
  `button/1`, `card/1`, `header/1`, `icon/1`, `input/1`, `flash/1`,
  `flash_group/1`, `list/1`, `table/1`. Each carries
  `data-component="JobyKit.CoreComponents.<name>"`, declares attrs with
  `values:` enums, accepts `attr :rest, :global`, and treats `class` as
  additive on top of the daisy primitive class set. Plus
  `show/2`/`hide/2` JS helpers and a Gettext-free `translate_error/1`.

* `JobyKit.NavComponent` — `simple_nav/1`, a daisyUI navbar primitive
  with active-link highlighting. Used in the kit-flavored `Layouts.app`
  generated by `mix joby_kit.new`.

### Patchers (idempotent host-file editors)

* `JobyKit.AgentsMd` — patches the host's `AGENTS.md` to (a) append the
  JobyKit guidelines section and (b) walk a list of rule-rewrites that
  replace stale Phoenix-default rules now superseded by the kit. Four
  rewrites ship: anti-daisy line, `<.input>` source rule, `<.input>`
  class-override rule, `<.icon>` source rule.

* `JobyKit.AppCss` — adds `@source "../../deps/joby_kit/lib";` to the
  host's `assets/css/app.css` so Tailwind v4 scans the kit for class
  names.

* `JobyKit.NavPatcher` — locates the first `<nav>` or `<header>` + `</ul>`
  in the host's `app.html.heex` (or `layouts.ex` as a fallback) and
  inserts kit nav links wrapped in `<%!-- jobykit:nav-* --%>` markers.
  Idempotent.

### Linting

* `JobyKit.Lint` — engine that verifies the wrapper contract by
  introspecting a manifest module and scanning the host's source. Four
  rules: `:manifest_drift` (entry points at non-existent function),
  `:missing_data_component` (registered wrapper missing the attribute),
  `:missing_rest_global` (registered wrapper missing
  `attr :rest, :global`), `:unregistered_wrapper` (function emits
  `data-component` but isn't in the manifest).

### Mix tasks

* `mix joby_kit.install` — installs into an existing Phoenix project:
  generates `design_manifest.ex`, `design_previews.ex`, the two design
  LiveViews, patches `AGENTS.md`, patches `assets/css/app.css`, and
  patches the host's nav with `/design` / `/custom-designs` links.

* `mix joby_kit.bootstrap` — composes `install` with greenfield steps
  for an already-generated `phx.new` project: replaces the default
  HomeLive, rewires `router.ex`, and removes the unused
  PageController/PageHTML.

* `mix joby_kit.new <app_name>` — wraps `mix phx.new` to generate a new
  Phoenix app with JobyKit baked in: replaces `<app>_web.ex`, layouts,
  and router with kit-flavored variants; deletes the redundant Phoenix
  scaffolding; runs `mix joby_kit.install`; runs `mix assets.setup`
  and `mix assets.build` so `mix phx.server` works on the first try.

* `mix joby_kit.gen.wrapper <name>` — scaffolds a new wrapper component
  end-to-end: function skeleton with the contract baked in, manifest
  entry registered, preview function added.

* `mix joby_kit.lint` — CLI for the lint engine. Auto-detects the
  host's manifest, supports `--format json` for agent consumption, and
  `--strict` to fail on warnings.
