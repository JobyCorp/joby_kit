defmodule JobyKit.AgentsMd do
  @moduledoc false

  # Helpers for patching the host's AGENTS.md file during install.
  #
  # Two transformations are applied (both idempotent, both safe to re-run):
  #
  #   * Append a `<!-- jobykit:start -->` … `<!-- jobykit:end -->` block
  #     describing how to use the kit.
  #   * Replace Phoenix's default "manually write your own tailwind-based
  #     components instead of using daisyUI" instruction with a
  #     daisyUI-friendly variant. The original line directly contradicts
  #     the kit's premise; without this patch agents reading the file get
  #     conflicting guidance.

  @start_marker "<!-- jobykit:start -->"
  @end_marker "<!-- jobykit:end -->"

  @phoenix_anti_daisy_pattern ~r/^- \*\*Always\*\* manually write your own tailwind-based components instead of using daisyUI[^\n]*$/m

  @phoenix_anti_daisy_replacement """
  - **Always** use the daisyUI primitives via this app's core wrappers (registered in `design_manifest.ex` and surfaced on `/design`). When daisyUI doesn't have a primitive that fits, build a wrapper from Tailwind first and register it — see the JobyKit guidelines below for the full build order
  """

  @doc """
  Patches `path` (typically `AGENTS.md`) so that it (a) carries a
  JobyKit guidelines block and (b) doesn't contain Phoenix's
  daisyUI-forbidding instruction.

  Creates the file if it does not exist. Returns one of
  `:created | :patched | :unchanged` so the calling mix task can print
  the right summary line.

  Pass `section: "...string..."` to override the appended block (used
  by tests).
  """
  def patch(path, opts \\ []) do
    section = Keyword.get_lazy(opts, :section, &default_section/0)

    {existing, file_existed?} =
      case File.read(path) do
        {:ok, contents} -> {contents, true}
        {:error, _} -> {"", false}
      end

    {replaced, replaced?} = replace_anti_daisy(existing)
    {with_block, appended?} = ensure_block(replaced, section)

    cond do
      not file_existed? ->
        File.write!(path, with_block)
        :created

      replaced? or appended? ->
        File.write!(path, with_block)
        :patched

      true ->
        :unchanged
    end
  end

  @doc "Returns the canonical JobyKit AGENTS.md section."
  def default_section do
    Application.app_dir(:joby_kit, ["priv", "templates", "joby_kit.install", "AGENTS.md.section"])
    |> File.read!()
  end

  defp replace_anti_daisy(contents) do
    case Regex.run(@phoenix_anti_daisy_pattern, contents) do
      nil ->
        {contents, false}

      [match] ->
        {Regex.replace(@phoenix_anti_daisy_pattern, contents, String.trim_trailing(@phoenix_anti_daisy_replacement), global: false)
         |> tap(fn _ -> match end), true}
    end
  end

  defp ensure_block(contents, section) do
    if String.contains?(contents, @start_marker) and String.contains?(contents, @end_marker) do
      {contents, false}
    else
      separator = if String.ends_with?(contents, "\n") or contents == "", do: "", else: "\n"
      trailing = if String.ends_with?(section, "\n"), do: "", else: "\n"
      {contents <> separator <> section <> trailing, true}
    end
  end
end
