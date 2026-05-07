# Changelog

## v0.1.0 — Unreleased

Initial extraction from the Bardo project. JobyKit ships:

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
