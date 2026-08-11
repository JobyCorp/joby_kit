# Changelog

## Unreleased (0.3.0 line)

**Breaking, on purpose.** See [MIGRATING-0.3.md](MIGRATING-0.3.md) for the
upgrade, including the list of compensating hacks to delete.

Removes the spacing and typography opinions host apps were routing
around, and fills in the variants they were hand-rolling. Driven by
usage data from three consumer apps: adoption turned out to be inversely
proportional to baked-in opinion — `button`/`input` (shape and behaviour,
nothing to undo) got hundreds of uses, while `card`/`header`/`list`
(typography and margin opinions) got bypassed. One app carried 127
hand-rolled panels against 10 `<.card>` uses; another had zero
`<.header>` uses and the same header class string pasted ten times.

* **`input/1`: `class` moves to the root.** It landed on the control, so
  the field group's own box was unreachable — callers resorted to
  nudging neighbouring elements (`class="mb-0.5"` on an adjacent button
  that didn't even work). `class` and layout now target the root
  `<fieldset>`, matching every other wrapper; the new `input_class`
  styles the control. Global attributes still reach the control, since
  `placeholder`/`required`/etc. would be meaningless on a fieldset.
* **`input/1`: no outer margin.** The hardcoded `mb-2` is gone —
  containers own spacing via `space-y-*`/`gap-*`. Width now works
  through the root (`class="w-32"`); the control is always `w-full`.
  The root is a semantic `<fieldset>`, and errors are associated with
  the control via `aria-invalid` and `aria-describedby`, so screen
  readers get more than a red border.
* **`card/1`: body typography is opt-in.** The forced
  `text-sm text-base-content/70` wrapper is gone, and body content
  renders as direct children of `card-body` — so the card's own `gap`
  applies instead of being dead weight behind a single wrapper div.
  `prose` opts into the old treatment; `body_class` sets your own.
  `card-actions` lost its hardcoded `mt-3`.
* **`header/1`: usable at last.** `pb-4` removed; new `:eyebrow` slot
  (both header-consuming apps hand-rolled one), `level` so a section
  header stops emitting a second `<h1>`, `size` (`page`/`section`), and
  `title_class` for apps with their own display face.
* **`button/1`: tones, `xs`, and shapes.** `variant` takes
  `soft | primary | neutral | ghost | danger`. Destructive actions can
  finally read as destructive — previously Revoke, Delete and Purge
  rendered identically to Refresh. The default is unchanged and is now
  nameable as `soft` for computed callers. `shape` (`circle`/`square`)
  covers icon-only buttons, replacing stacks like
  `btn btn-primary btn-soft btn-sm btn-ghost btn-circle` where four
  competing classes were resolved only by stylesheet order.
* **`table/1`: additive hooks.** An `:empty` slot (five pages in one app
  repeated the `:if={@rows != []}` + `<.empty_state>` pair), `zebra`
  opt-out, a `size` density enum instead of leaking `table-xs` through
  `class`, and `data-table-actions` on the action cell so overrides can
  target it precisely — one app's `:last-child` workaround was hitting a
  data column on tables with no `:action` slot.

### Linter

The `:raw_html_primitive` rule is the kit's headline check, and it was
both over- and under-firing. **Expect new findings after upgrading** —
they are real, previously hidden.

* **The exemption is now scoped to the enclosing `def`, not the file.**
  Any file containing `data-component=` *anywhere* — including in a
  comment or a docstring — silenced the rule for the whole file. One
  small wrapper in a 500-line LiveView zeroed coverage for the entire
  render, and a `# data-component=` comment disabled the check
  wholesale without the audit trail the documented escape hatch leaves.
  A `def` whose body carries `data-component=` is still treated as
  wrapper territory; everything else in the file is checked. The kit's
  own fixtures gained a finding the moment this landed.
* **Prose is no longer mistaken for markup.** `@doc`/`@moduledoc`
  heredocs and HEEx/HTML comments are blanked (newlines preserved)
  before scanning. The kit's own `composite_components.ex` template
  spells out `data-component="<App>Web.CompositeComponents.<name>"` and
  says "never raw `<button>`/`<input>`/`<textarea>`" — so **every
  freshly installed host opened with four phantom warnings**, one of
  them quoting the sentence telling them not to do it. A clean install
  now lints clean.
* **Every primitive on a line is reported**, not just the first
  (`Regex.scan`, not `Regex.run`) — fixing one used to reveal the next.
* **Capitalised remote components are no longer flagged.** The tag
  regex was case-insensitive, so `<Input.autocomplete />` read as a raw
  `<input>`. HEEx reserves lowercase for HTML and capitalised for
  components; the regex now matches accordingly.
* `~H'''` heredocs are scanned (the sigil pattern missed the
  single-quote delimiter, so those files were skipped entirely).
* The violation message no longer suggests `# jobykit:allow-raw-html`
  inside a template — in a `~H` block a `#` line is literal text that
  renders into the page.

Two new rules, both from demonstrated harm in consumer apps:

* **`:forked_wrapper` (warning)** — flags components excluded from
  `import JobyKit.CoreComponents` and replaced with a host copy. One app
  forked `button/1` and `table/1`; the 0.2.1 `table/1` fix shipped into
  a component it never renders, while its fork carried the identical
  bug. Nothing surfaced that. Entries now also carry
  `forked_from_kit` in `/design.json`, so "did that fix reach us?" is a
  lookup instead of an archaeology exercise.
* **`:duplicated_class_string` (warning)** — the same ≥25-character
  `class` string appearing three or more times. The kit's own CLAUDE.md
  names this as the symptom that markup wants lifting into a wrapper,
  but nothing checked it: one app pasted the same header class string
  ten times and linted clean.

### `mix joby_kit.new` moved to its own package

**Action required if you install the archive:**

```sh
mix archive.uninstall joby_kit
mix archive.install hex joby_kit_new
```

The generator now lives at
[joby_kit_new](https://github.com/JobyCorp/joby_kit_new). Nothing else
changes — `joby_kit.install`, `bootstrap`, `gen.wrapper` and `lint` stay
in this package, which is the point.

`joby_kit.new` has to run before a project exists, so it can only be a
Mix archive — and an archive puts *everything it contains* on the global
code path. With the in-project tasks in the same package, the archive's
copy of them shadowed each project's own dependency. Concretely: with a
project pinned to 0.2.3 and a 0.2.0 archive installed,
`mix joby_kit.install` generated 0.2.0 scaffolding, and re-running
changed nothing. **An app's `mix.exs` did not control which JobyKit
generated its files** — whichever archive was on the machine did. That
also explains generated-file drift across a fleet.

Only `joby_kit.lint` escaped, by accident: it declares
`@requirements ["compile"]`, which loads the project's dependencies
first, so the dependency's copy won.

Splitting removes the possibility instead of detecting it, and follows
Phoenix's arrangement — `phx_new` is a separate hex package from
`phoenix`. A version guard was considered and rejected: Mix gives no way
to prefer the dependency's task over an archive's, so a warning would
have left users stuck rather than fixed.

### New components

Three of the four components consumers had built for themselves. The
fourth, an icon button, is covered by `button/1`'s new `shape`.

* **`badge/1`** — status chip with a semantic tone
  (`neutral | ok | warn | danger | info`). One app maintained five
  separate tone-to-class functions mapping the same states to
  border+bg+text triples, and had copied one of them verbatim into a
  second file — precisely the drift the kit's guidance warns about.
  `neutral` and `danger` deliberately mean the same thing here as on
  `button/1`.
* **`eyebrow/1`** — the small uppercase label. This was the single
  most-duplicated string in the fleet: 326 hand-typed instances in one
  app, with letter-spacing drifting across nine values and six font
  sizes. `card/1` and `header/1` now render their `:eyebrow` slots
  through it, so the kit stops carrying three copies of the string
  itself.
* **`modal/1`** — server-driven dialog. Two apps built one and both hit
  the same three problems, so those are what it solves: visibility is a
  plain assign rather than client state, so it can't disagree with the
  LiveView that owns it; one `on_cancel` covers the close button, the
  backdrop, and Escape, instead of the separate close/dismiss handlers
  apps ended up writing; and `static` renders the box in flow for design
  pages, since `.modal` is `position: fixed` and would otherwise cover
  the page it's being previewed on.
* **`list/1` loosened rather than demoted.** It had zero uses in one app
  and was bypassed in another because the forced `font-bold` title
  couldn't be overridden; `title_class` replaces it. It stays a `ul`
  because daisy's `list` requires that shape. The starter page's build
  order now uses it.

Registering these surfaced a small proof the new linter works: the
shipped previews template repeated one layout string four times and
tripped `:duplicated_class_string` on a fresh install. Extracted to a
private helper — a fresh install lints clean again.

### Starter app and theming

The generated app is the kit's own worked example, so it has to be
exemplary. It wasn't: it hand-rolled markup the linter would flag, and
it dropped the theme switching every `mix phx.new` app ships with.

* **New `theme_toggle/1`** — a segmented system / light / dark control,
  registered and previewed like any other wrapper. `mix joby_kit.new`
  restores the theme script Phoenix puts in `root.html.heex` (which
  applies the stored choice before first paint, so there's no flash) and
  wires the control into the layout. Phoenix builds its version from raw
  `<button>` elements; this one composes `<.button shape="square">`, so
  the kit's own chrome satisfies the contract the kit enforces.
* **`simple_nav/1` no longer paints its own surface, and accepts globals.**
  It carried `bg-base-100 border-b`, which produced a visible seam
  wherever a layout wrapped it in its own sticky bar: the bar's
  translucent background showed at the edges while the nav painted an
  opaque strip only as wide as its max-width container. Surface belongs
  to the container. It also gains an `:actions` slot for trailing
  controls, `aria-current="page"` on the active link, and the
  `attr :rest, :global` it was missing — the kit's own component had
  been violating the contract.
* **`simple_nav` and `theme_toggle` are registered** in the shipped
  manifest, with previews, so both appear on `/design` and in
  `/design.json`. The daisy catalogue's `navbar` and `theme-controller`
  entries now read as wrapped.
* **The landing page is a worked example rather than a welcome page.**
  It hand-rolled a header, nested a second `<main>` inside the layout's,
  and styled sections with one-off classes. It's now built entirely from
  wrappers — `<.header>` with the new `:eyebrow`, `<.card>`, `<.list>`
  for the build order (a real sequence, so the numbering carries
  information) — and each section names the component that renders it.
* **Signature cards: long attr defaults no longer collide with the attr
  name.** The row is a two-column grid whose second track sized to
  max-content, so a default like `simple_nav`'s link list overflowed
  across the label. Long defaults now take the full-width row that
  `values:` already used.

### Generators

* **`mix joby_kit.new --no-dashboard` / `--no-mailer` produced apps that
  don't compile.** Both flags are advertised as forwarded to `phx.new`,
  but the router template referenced `Phoenix.LiveDashboard.Router` and
  `Plug.Swoosh.MailboxPreview` unconditionally. The template is now
  conditional, and drops the whole `/dev` scope when neither is present.
  All four flag combinations are parse-checked in the suite.
* **`mix joby_kit.new` no longer silently half-succeeds.** If the
  `defp deps do [` regex didn't match the generated `mix.exs`,
  `Regex.replace/4` returned the source unchanged — the task printed
  "* updating mix.exs" and the failure surfaced much later as an
  unrelated-looking error about undefined `JobyKit` modules. It now
  verifies the dep landed and raises with the line to add by hand.
* **The generated web module keeps Gettext wired.** It dropped
  phx.new's `use Gettext, backend: …` while the app still shipped the
  backend, so any `gettext(...)` call in a template failed to compile.
  Now included, and omitted only for `--no-gettext`.
* **`mix joby_kit.bootstrap`'s home page no longer models the
  anti-pattern the kit polices.** It hand-rolled
  `card card-bordered` / `btn btn-primary` markup instead of using the
  wrappers — and `card-bordered` has been dead since daisyUI 5 (the v5
  name is `card-border`), so the "bordered" card wasn't even bordered.
  Now uses `<JobyKit.CoreComponents.card>` / `.button`, fully qualified
  because bootstrap runs against an existing app whose own
  `CoreComponents` may still be imported.
* **`mix joby_kit.gen.wrapper --category composite` scaffolded a module
  that couldn't hold a real composite.** A fresh
  `composite_components.ex` got a bare `use Phoenix.Component`, so the
  first `<.icon>` or `~p"/..."` in the new composite failed to compile —
  and the kit's own worked example uses both. It now matches the install
  template: `use <App>Web, :html`.
* Tests: generated output is parsed (`Code.string_to_quoted`) across
  install, bootstrap, and gen.wrapper. Nothing had ever checked that the
  code these tasks write is syntactically valid; the suite asserted on
  strings only. Install also asserts the expected file count, so a
  template added without a test can't slip by.

## Unreleased (catalogue)

Reconciles `DaisyCatalogue` with daisyUI 5.7.16, verified against the
published package rather than the docs prose.

* **Two demos taught removed daisyUI 4 classes.** The card demo used
  `card-compact` (v5 replaced the single compact modifier with the
  `card-xs/sm/md/lg/xl` scale) and the label demo used `label-text` (v5
  dropped the `form-control`/`label-text` pairing entirely). Both are
  absent from 5.7.16's CSS — confirmed by grepping the shipped
  `components/*.css`. The page that exists to be the reference was
  teaching a dead API.
* **Nine docs links 404'd.** `docs_url/1` derived the URL from the
  display name, which breaks wherever our label differs from daisy's
  page name — "Chat bubble" → `/components/chat-bubble/`, "Text Input"
  → `/components/text-input/`, all four mockups reversed
  (`browser-mockup` vs `mockup-browser`), and so on. Entries now carry
  an optional `:docs_slug`, and `docs_url/1` accepts a catalogue entry
  (the bare-name form still works). Every one of the 68 links was
  checked against daisyui.com and now resolves.
* **Six primitives were missing**, all added after 5.0: `hover-gallery`
  (5.1), `hover-3d` and `text-rotate` (5.5), `aura`, `megamenu`, and
  `otp` (5.6). Each carries a `:since` key and says so in its note,
  because hosts vendor their own `assets/vendor/daisyui.js` — a host on
  an older bundle simply does not have those classes. `daisy_version/0`
  now reports which daisy release the catalogue was verified against.
* **`merged/1` silently dropped every daisy override for a manifest
  module that happened not to be loaded yet.** `function_exported?/3`
  answers false for an unloaded module, so wrapped primitives showed as
  unwrapped depending on load order. Now guarded with
  `Code.ensure_loaded?/1`.
* Tests: a `:external`-tagged case verifies every docs link over the
  network (excluded by default; `mix test --include external`), plus
  guards that no demo reintroduces a removed v4 class and that every
  `:since` entry names its version in its note. Also fixed a
  seed-dependent flake in the new lint-task tests, where Mix's own
  `==> app` banner interleaved with captured task output.

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
