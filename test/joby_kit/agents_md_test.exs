defmodule JobyKit.AgentsMdTest do
  use ExUnit.Case, async: true

  alias JobyKit.AgentsMd

  @moduletag :tmp_dir

  test "creates AGENTS.md when missing", %{tmp_dir: dir} do
    path = Path.join(dir, "AGENTS.md")

    assert AgentsMd.patch(path) == :created
    contents = File.read!(path)
    assert contents =~ "<!-- jobykit:start -->"
    assert contents =~ "<!-- jobykit:end -->"
    assert contents =~ "JobyKit guidelines"
  end

  test "appends the JobyKit block to an existing AGENTS.md", %{tmp_dir: dir} do
    path = Path.join(dir, "AGENTS.md")
    File.write!(path, "# Existing project notes\n\nKeep this content intact.\n")

    assert AgentsMd.patch(path) == :patched
    contents = File.read!(path)
    assert contents =~ "Existing project notes"
    assert contents =~ "Keep this content intact."
    assert contents =~ "<!-- jobykit:start -->"
  end

  test "replaces Phoenix's daisyUI-forbidding line", %{tmp_dir: dir} do
    path = Path.join(dir, "AGENTS.md")

    File.write!(path, """
    # AGENTS

    - some other rule
    - **Always** manually write your own tailwind-based components instead of using daisyUI for a unique, world-class design
    - one more rule
    """)

    assert AgentsMd.patch(path) == :patched
    contents = File.read!(path)

    refute contents =~ "manually write your own tailwind-based components instead of using daisyUI"
    assert contents =~ "use the daisyUI primitives via this app's core wrappers"
    assert contents =~ "some other rule"
    assert contents =~ "one more rule"
  end

  test "is idempotent: re-running yields :unchanged", %{tmp_dir: dir} do
    path = Path.join(dir, "AGENTS.md")
    File.write!(path, "# Project\n")

    assert AgentsMd.patch(path) == :patched
    assert AgentsMd.patch(path) == :unchanged

    contents = File.read!(path)
    [_, _] = String.split(contents, "<!-- jobykit:start -->")
  end

  test "is idempotent even when both transformations apply", %{tmp_dir: dir} do
    path = Path.join(dir, "AGENTS.md")

    File.write!(path, """
    # Project

    - **Always** manually write your own tailwind-based components instead of using daisyUI for a unique, world-class design
    """)

    assert AgentsMd.patch(path) == :patched
    assert AgentsMd.patch(path) == :unchanged
  end
end
