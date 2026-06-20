defmodule JobyKit.ClaudeMd do
  @moduledoc false

  # Helpers for patching the host's CLAUDE.md file during install.
  #
  # CLAUDE.md sits at the project root and is auto-loaded into Claude
  # Code's context every session. We use it to surface the highest-
  # priority wrapper-contract diagnostics — particularly the "symptoms
  # you skipped step 1" list — so an agent doesn't have to know to open
  # AGENTS.md to find them.
  #
  # The patcher mirrors `JobyKit.AgentsMd`: idempotent, marker-bracketed,
  # safe to re-run. Only the appended block is written; existing content
  # in the file is left intact.

  @start_marker "<!-- jobykit:start -->"
  @end_marker "<!-- jobykit:end -->"

  @doc """
  Patches `path` (typically `CLAUDE.md`). Creates the file if missing,
  appends the JobyKit block if absent, no-ops if already present.

  Returns one of `:created | :patched | :unchanged`.
  """
  def patch(path, opts \\ []) do
    section = Keyword.get_lazy(opts, :section, &default_section/0)

    {existing, file_existed?} =
      case File.read(path) do
        {:ok, contents} -> {contents, true}
        {:error, _} -> {"", false}
      end

    {with_block, appended?} = ensure_block(existing, section)

    cond do
      not file_existed? ->
        File.write!(path, with_block)
        :created

      appended? ->
        File.write!(path, with_block)
        :patched

      true ->
        :unchanged
    end
  end

  @doc "Returns the canonical JobyKit CLAUDE.md section."
  def default_section do
    Application.app_dir(:joby_kit, ["priv", "templates", "joby_kit.install", "CLAUDE.md.section"])
    |> File.read!()
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
