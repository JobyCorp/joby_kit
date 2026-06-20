defmodule JobyKit.ClaudeMdTest do
  use ExUnit.Case, async: true

  alias JobyKit.ClaudeMd

  @moduletag :tmp_dir

  test "creates CLAUDE.md when missing", %{tmp_dir: dir} do
    path = Path.join(dir, "CLAUDE.md")

    assert ClaudeMd.patch(path) == :created
    contents = File.read!(path)
    assert contents =~ "<!-- jobykit:start -->"
    assert contents =~ "<!-- jobykit:end -->"
    assert contents =~ "JobyKit"
    assert contents =~ "Symptoms you skipped step 1"
  end

  test "appends the JobyKit block to an existing CLAUDE.md", %{tmp_dir: dir} do
    path = Path.join(dir, "CLAUDE.md")
    File.write!(path, "# Existing project notes\n\nKeep this content intact.\n")

    assert ClaudeMd.patch(path) == :patched
    contents = File.read!(path)
    assert contents =~ "Existing project notes"
    assert contents =~ "Keep this content intact."
    assert contents =~ "<!-- jobykit:start -->"
    assert contents =~ "Symptoms you skipped step 1"
  end

  test "is idempotent: re-running yields :unchanged", %{tmp_dir: dir} do
    path = Path.join(dir, "CLAUDE.md")
    File.write!(path, "# Project\n")

    assert ClaudeMd.patch(path) == :patched
    assert ClaudeMd.patch(path) == :unchanged

    contents = File.read!(path)
    [_, _] = String.split(contents, "<!-- jobykit:start -->")
  end

  test "default section inlines the raw-HTML diagnostic" do
    section = ClaudeMd.default_section()

    assert section =~ "raw `<button>`"
    assert section =~ "`<.button>`"
    assert section =~ "jobykit:allow-raw-html"
    assert section =~ "mix joby_kit.lint"
  end
end
