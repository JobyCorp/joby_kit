defmodule JobyKit.AppCss do
  @moduledoc false

  # Helpers for patching the host's `assets/css/app.css` during install.
  #
  # Tailwind v4 uses `@source` directives to discover class names. Class
  # names that live inside `deps/joby_kit/lib` won't be picked up unless
  # the host opts that path in, so kit components silently render
  # un-styled (e.g. `menu-horizontal` resolving to a vertical menu).
  #
  # The patch inserts a single line — `@source "../../deps/joby_kit/lib";`
  # — directly after the last existing `@source` directive. Idempotent
  # and safe to re-run.

  @source_line ~s|@source "../../deps/joby_kit/lib";|

  @doc """
  Patches `path` (typically `assets/css/app.css`) so Tailwind scans the
  installed JobyKit dependency for class names.

  Returns one of `:patched | :unchanged | :missing` so the caller can
  log a useful summary. `:missing` is returned when the host has no
  `app.css` file at all (e.g. a non-Phoenix project).
  """
  def patch(path \\ "assets/css/app.css") do
    case File.read(path) do
      {:error, _} ->
        :missing

      {:ok, contents} ->
        if String.contains?(contents, @source_line) do
          :unchanged
        else
          File.write!(path, insert_after_last_source(contents))
          :patched
        end
    end
  end

  @doc false
  def source_line, do: @source_line

  defp insert_after_last_source(contents) do
    lines = String.split(contents, "\n")

    case last_source_index(lines) do
      nil -> prepend_source(contents)
      idx -> List.insert_at(lines, idx + 1, @source_line) |> Enum.join("\n")
    end
  end

  defp last_source_index(lines) do
    lines
    |> Enum.with_index()
    |> Enum.filter(fn {line, _i} -> Regex.match?(~r/^\s*@source\b/, line) end)
    |> List.last()
    |> case do
      nil -> nil
      {_line, idx} -> idx
    end
  end

  defp prepend_source(contents) do
    @source_line <> "\n" <> contents
  end
end
