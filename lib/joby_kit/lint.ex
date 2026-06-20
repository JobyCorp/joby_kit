defmodule JobyKit.Lint do
  @moduledoc """
  Lint engine for JobyKit-installed apps. Verifies wrapper-contract
  invariants by introspecting a manifest module and scanning the host's
  component source files.

  ## Rules

    * `:manifest_drift` (error) — a manifest entry points at a function
      that is not actually a Phoenix function component. Caught first
      because every other check depends on the entry being live.
    * `:missing_data_component` (error) — a registered wrapper does not
      carry `data-component="Module.function"` in its source.
    * `:missing_rest_global` (warning) — a registered wrapper does not
      declare `attr :rest, :global`, blocking pass-through of phx-* and
      aria-* attributes from callers.
    * `:unregistered_wrapper` (warning) — a function carries a
      `data-component="..."` attribute but is not registered in the
      manifest, making it invisible to `/design.json` and to agents.
    * `:raw_html_primitive` (warning) — a `.heex` template (or `~H`
      block in a `.ex`) contains a raw `<button>`, `<input>`,
      `<textarea>`, or `<select>` outside of a wrapper definition. The
      kit ships wrappers for all four; reaching past them drops the
      contract. Whole-file skipped when the file contains
      `data-component=` (i.e., defines wrappers). Per-line opt-out via
      `<%!-- jobykit:allow-raw-html --%>` (or `# jobykit:allow-raw-html`
      on the preceding line for `.ex` files).

  Each violation is a map with `:rule`, `:severity`, `:message`,
  `:file`, `:line`, `:module`, `:function`. The engine is pure data —
  formatting and exit codes live in `Mix.Tasks.JobyKit.Lint`.
  """

  @type severity :: :error | :warning | :info

  @type violation :: %{
          rule: atom(),
          severity: severity(),
          message: String.t(),
          file: String.t() | nil,
          line: non_neg_integer() | nil,
          module: module() | nil,
          function: atom() | nil
        }

  @default_paths ["lib/**/*.ex", "lib/**/*.heex"]
  @data_component_re ~r/data-component=(?:"([^"]+)"|'([^']+)')/
  @raw_html_primitive_re ~r/<(button|input|textarea|select)\b/i
  @allow_raw_html_marker "jobykit:allow-raw-html"

  @doc """
  Run the lint engine. Returns a list of violations in deterministic
  order (drift first, then per-entry checks in manifest declaration
  order, then unregistered wrappers sorted by data-component string).

  ## Options

    * `:manifest` — required. The host's manifest module
      (`use JobyKit.Manifest`).
    * `:paths` — list of glob patterns to scan for the unregistered-
      wrapper rule. Defaults to `["lib/**/*.ex"]`. Patterns are
      resolved relative to `cwd`.
  """
  @spec run(keyword()) :: [violation()]
  def run(opts) do
    manifest = Keyword.fetch!(opts, :manifest)
    paths = Keyword.get(opts, :paths, @default_paths)

    Code.ensure_loaded!(manifest)
    entries = manifest.entries()

    {drift_violations, healthy_entries} = check_manifest_drift(entries)

    data_component_violations = Enum.flat_map(healthy_entries, &check_data_component/1)
    rest_global_violations = Enum.flat_map(healthy_entries, &check_rest_global/1)

    registered = MapSet.new(healthy_entries, & &1.data_component)
    unregistered_violations = scan_unregistered_wrappers(paths, registered)
    raw_html_violations = scan_raw_html_primitives(paths)

    drift_violations ++
      data_component_violations ++
      rest_global_violations ++ unregistered_violations ++ raw_html_violations
  end

  # -------------------------------------------------------- manifest_drift

  defp check_manifest_drift(entries) do
    Enum.reduce(entries, {[], []}, fn entry, {drift, healthy} ->
      cond do
        not Code.ensure_loaded?(entry.module) ->
          {[drift_violation(entry, "module is not loadable") | drift], healthy}

        not function_exported?(entry.module, entry.function, 1) ->
          {[drift_violation(entry, "function/1 does not exist") | drift], healthy}

        not phoenix_component?(entry.module, entry.function) ->
          {[drift_violation(entry, "function is not a Phoenix function component") | drift],
           healthy}

        true ->
          {drift, [entry | healthy]}
      end
    end)
    |> then(fn {drift, healthy} -> {Enum.reverse(drift), Enum.reverse(healthy)} end)
  end

  defp drift_violation(entry, reason) do
    %{
      rule: :manifest_drift,
      severity: :error,
      message:
        "manifest entry #{entry.data_component} is broken: #{reason}. Update or remove the component/3 line.",
      file: entry.source,
      line: entry.line,
      module: entry.module,
      function: entry.function
    }
  end

  defp phoenix_component?(module, function) do
    function_exported?(module, :__components__, 0) and
      Map.has_key?(module.__components__(), function)
  end

  # -------------------------------------------------- missing_data_component

  defp check_data_component(entry) do
    case read_source(entry) do
      {:ok, source} ->
        if String.contains?(source, ~s|data-component="#{entry.data_component}"|) or
             String.contains?(source, ~s|data-component='#{entry.data_component}'|) do
          []
        else
          [
            %{
              rule: :missing_data_component,
              severity: :error,
              message:
                ~s|wrapper #{entry.data_component} does not carry data-component="#{entry.data_component}" on its root element|,
              file: entry.source,
              line: entry.line,
              module: entry.module,
              function: entry.function
            }
          ]
        end

      :error ->
        []
    end
  end

  defp read_source(%{source: nil}), do: :error

  defp read_source(%{source: path}) do
    case File.read(path) do
      {:ok, contents} -> {:ok, contents}
      {:error, _} -> :error
    end
  end

  # ----------------------------------------------------- missing_rest_global

  defp check_rest_global(entry) do
    attrs = raw_attrs(entry.module, entry.function)

    if Enum.any?(attrs, &(&1.name == :rest and &1.type == :global)) do
      []
    else
      [
        %{
          rule: :missing_rest_global,
          severity: :warning,
          message:
            "wrapper #{entry.data_component} is missing `attr :rest, :global` — callers cannot pass id/class/aria-*/phx-* through",
          file: entry.source,
          line: entry.line,
          module: entry.module,
          function: entry.function
        }
      ]
    end
  end

  defp raw_attrs(module, function) do
    case Map.get(module.__components__(), function) do
      %{attrs: attrs} when is_list(attrs) -> attrs
      _ -> []
    end
  end

  # ---------------------------------------------------- unregistered_wrapper

  defp scan_unregistered_wrappers(patterns, registered) do
    patterns
    |> Enum.flat_map(&Path.wildcard/1)
    |> Enum.uniq()
    |> Enum.flat_map(&scan_file_for_data_components/1)
    |> Enum.reject(fn %{data_component: dc} -> MapSet.member?(registered, dc) end)
    |> Enum.uniq_by(& &1.data_component)
    |> Enum.sort_by(& &1.data_component)
    |> Enum.map(&unregistered_violation/1)
  end

  defp scan_file_for_data_components(path) do
    case File.read(path) do
      {:ok, contents} ->
        line_index = build_line_index(contents)

        Regex.scan(@data_component_re, contents, return: :index)
        |> Enum.map(fn match ->
          {start, _len} = match |> Enum.drop(1) |> Enum.find(&(&1 != {-1, 0}))
          dc = capture_value(contents, match)
          %{data_component: dc, file: path, line: line_for_offset(line_index, start)}
        end)
        |> Enum.reject(&(&1.data_component == nil))

      {:error, _} ->
        []
    end
  end

  defp capture_value(contents, [_full | captures]) do
    captures
    |> Enum.find(&(&1 != {-1, 0}))
    |> case do
      nil -> nil
      {start, len} -> binary_part(contents, start, len)
    end
  end

  defp build_line_index(contents) do
    contents
    |> String.split("\n")
    |> Enum.scan(0, fn line, acc -> acc + byte_size(line) + 1 end)
  end

  defp line_for_offset(line_index, offset) do
    Enum.find_index(line_index, &(&1 > offset)) |> Kernel.||(0) |> Kernel.+(1)
  end

  defp unregistered_violation(%{data_component: dc, file: file, line: line}) do
    %{
      rule: :unregistered_wrapper,
      severity: :warning,
      message:
        "#{dc} carries data-component but is not registered in the manifest — it is invisible to /design.json and to agents",
      file: file,
      line: line,
      module: nil,
      function: nil
    }
  end

  # ----------------------------------------------------- raw_html_primitive

  defp scan_raw_html_primitives(patterns) do
    patterns
    |> Enum.flat_map(&Path.wildcard/1)
    |> Enum.uniq()
    |> Enum.flat_map(&scan_file_for_raw_primitives/1)
    |> Enum.sort_by(&{&1.file, &1.line})
  end

  defp scan_file_for_raw_primitives(path) do
    case File.read(path) do
      {:ok, contents} ->
        cond do
          not heex_bearing?(path, contents) -> []
          wrapper_territory?(contents) -> []
          true -> find_raw_primitives_in(path, contents)
        end

      {:error, _} ->
        []
    end
  end

  # A file is HEEx-bearing if it's a .heex template or contains a `~H`
  # sigil. Pure .ex files without `~H` (mix tasks, GenServers, etc.)
  # have no templates to lint. The sigil regex requires a delimiter
  # character immediately after `~H` so a comment that *mentions* `~H`
  # in prose doesn't flip a file into scannable mode.
  @sigil_h_re ~r/~H["\[\(\{<\/\|]/
  defp heex_bearing?(path, contents) do
    Path.extname(path) == ".heex" or Regex.match?(@sigil_h_re, contents)
  end

  # A file is "wrapper territory" if it contains `data-component=`
  # anywhere — that means at least one wrapper definition lives here,
  # and the rest of the file is treated as legitimate wrapper internals.
  # File-level granularity is the v1 trade-off; per-function granularity
  # would require AST parsing.
  defp wrapper_territory?(contents) do
    String.contains?(contents, "data-component=")
  end

  defp find_raw_primitives_in(path, contents) do
    lines = String.split(contents, "\n")

    lines
    |> Enum.with_index(1)
    |> Enum.flat_map(fn {line, line_no} ->
      case Regex.run(@raw_html_primitive_re, line, return: :index) do
        [{tag_offset, _}, {tag_start, tag_len}] ->
          tag = binary_part(line, tag_start, tag_len)

          cond do
            allows_raw_html?(line, lines, line_no) -> []
            in_string_literal?(line, tag_offset) -> []
            true -> [raw_html_violation(path, line_no, tag)]
          end

        _ ->
          []
      end
    end)
  end

  defp allows_raw_html?(line, lines, line_no) do
    String.contains?(line, @allow_raw_html_marker) or
      case Enum.at(lines, line_no - 2) do
        nil -> false
        prev -> String.contains?(prev, @allow_raw_html_marker)
      end
  end

  # Heuristic: if the match is preceded by an odd number of unescaped
  # double-quotes on the same line, it's likely inside an Elixir string
  # literal (e.g. a docstring or an error message that mentions
  # `<button>`), not a real HEEx tag. Skip.
  defp in_string_literal?(line, match_offset) do
    line
    |> binary_part(0, match_offset)
    |> String.replace("\\\"", "")
    |> count_chars(?")
    |> rem(2)
    |> Kernel.==(1)
  end

  defp count_chars(string, char) do
    for <<c <- string>>, c == char, reduce: 0 do
      acc -> acc + 1
    end
  end

  defp raw_html_violation(path, line_no, tag) do
    suggestion =
      case String.downcase(tag) do
        "button" -> "use `<.button>` (or register a new wrapper for icon/ghost variants)"
        "input" -> "use `<.input>`"
        "textarea" -> "use `<.input type=\"textarea\">` (or register a new wrapper)"
        "select" -> "use `<.input type=\"select\">` (or register a new wrapper)"
        _ -> "lift this primitive into a registered wrapper"
      end

    %{
      rule: :raw_html_primitive,
      severity: :warning,
      message:
        "raw <#{tag}> outside a wrapper definition — #{suggestion}. " <>
          "Silence with `<%!-- #{@allow_raw_html_marker} --%>` (heex) " <>
          "or `# #{@allow_raw_html_marker}` on the preceding line (.ex).",
      file: path,
      line: line_no,
      module: nil,
      function: nil
    }
  end
end
