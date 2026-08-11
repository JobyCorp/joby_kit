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

    refute contents =~
             "manually write your own tailwind-based components instead of using daisyUI"

    assert contents =~ "When a primitive UI need matches an existing core wrapper"
    assert contents =~ "reuse and discoverability of existing app components"
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

  describe "rule rewrites for kit-owned components" do
    test "rewrites Phoenix's <.input> rule to point at JobyKit.CoreComponents", %{tmp_dir: dir} do
      path = Path.join(dir, "AGENTS.md")

      File.write!(path, """
      # AGENTS

      - **Always** use the imported `<.input>` component for form inputs from `core_components.ex` when available. `<.input>` is imported and using it will save steps and prevent errors
      - other rule
      """)

      AgentsMd.patch(path)
      contents = File.read!(path)

      refute contents =~ "from `core_components.ex` when available"
      assert contents =~ "from `JobyKit.CoreComponents`"
      assert contents =~ "other rule"
    end

    test "rewrites the <.input> class-override rule to reflect additive semantics",
         %{tmp_dir: dir} do
      path = Path.join(dir, "AGENTS.md")

      File.write!(path, """
      # AGENTS

      - If you override the default input classes (`<.input class="myclass px-2 py-1 rounded-lg">)`) class with your own values, no default classes are inherited, so your
      custom classes must fully style the input
      """)

      AgentsMd.patch(path)
      contents = File.read!(path)

      refute contents =~ "no default classes are inherited"
      assert contents =~ "additive on top of the daisyUI defaults"
    end

    test "rewrites Phoenix's <.icon> rule to point at JobyKit.CoreComponents",
         %{tmp_dir: dir} do
      path = Path.join(dir, "AGENTS.md")

      File.write!(path, """
      # AGENTS

      - Out of the box, `core_components.ex` imports an `<.icon name="hero-x-mark" class="w-5 h-5"/>` component for hero icons. **Always** use the `<.icon>` component for icons, **never** use `Heroicons` modules or similar
      """)

      AgentsMd.patch(path)
      contents = File.read!(path)

      refute contents =~ "Out of the box, `core_components.ex` imports"
      assert contents =~ "from `JobyKit.CoreComponents`"
      assert contents =~ "Never** use `Heroicons` modules"
    end

    test "is idempotent across all rewrites", %{tmp_dir: dir} do
      path = Path.join(dir, "AGENTS.md")

      File.write!(path, """
      # AGENTS

      - **Always** manually write your own tailwind-based components instead of using daisyUI for a unique, world-class design
      - **Always** use the imported `<.input>` component for form inputs from `core_components.ex` when available. Foo
      - Out of the box, `core_components.ex` imports an `<.icon name="hero-x-mark" class="w-5 h-5"/>` component for hero icons. **Always** use the `<.icon>` component for icons, **never** use `Heroicons` modules or similar
      """)

      assert AgentsMd.patch(path) == :patched
      assert AgentsMd.patch(path) == :unchanged
    end
  end
end
