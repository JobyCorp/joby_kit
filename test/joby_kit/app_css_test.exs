defmodule JobyKit.AppCssTest do
  use ExUnit.Case, async: true

  alias JobyKit.AppCss

  @moduletag :tmp_dir

  @source_line ~s|@source "../../deps/joby_kit/lib";|

  test "adds @source line after the last existing @source directive", %{tmp_dir: dir} do
    path = Path.join(dir, "app.css")

    File.write!(path, """
    @import "tailwindcss" source(none);
    @source "../css";
    @source "../js";
    @source "../../lib/my_app_web";

    @plugin "../vendor/heroicons";
    """)

    assert AppCss.patch(path) == :patched
    contents = File.read!(path)

    assert contents =~ @source_line

    # New line lands after the last @source, before the @plugin block.
    last_source_idx =
      contents
      |> String.split("\n")
      |> Enum.find_index(&(&1 == @source_line))

    plugin_idx =
      contents
      |> String.split("\n")
      |> Enum.find_index(&String.contains?(&1, "@plugin"))

    assert last_source_idx < plugin_idx
  end

  test "is idempotent: re-running yields :unchanged", %{tmp_dir: dir} do
    path = Path.join(dir, "app.css")
    File.write!(path, ~s|@source "../css";\n|)

    assert AppCss.patch(path) == :patched
    assert AppCss.patch(path) == :unchanged

    contents = File.read!(path)
    occurrences = contents |> String.split(@source_line) |> length()
    assert occurrences == 2
  end

  test "returns :missing when app.css does not exist", %{tmp_dir: dir} do
    path = Path.join(dir, "app.css")

    assert AppCss.patch(path) == :missing
    refute File.exists?(path)
  end

  test "prepends the @source line if no existing @source directives", %{tmp_dir: dir} do
    path = Path.join(dir, "app.css")
    File.write!(path, "/* nothing here */\n")

    assert AppCss.patch(path) == :patched
    contents = File.read!(path)

    assert String.starts_with?(contents, @source_line)
    assert contents =~ "/* nothing here */"
  end
end
