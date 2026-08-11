defmodule JobyKit.CoreComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]

  alias JobyKit.CoreComponents

  describe "wrapper contract" do
    test "every shipped component carries data-component on its root" do
      assigns = %{rows: [%{name: "Mira"}], flash: %{"info" => "hi"}, empty_flash: %{}}

      icon = rendered_to_string(~H|<CoreComponents.icon name="hero-x-mark" />|)
      button = rendered_to_string(~H|<CoreComponents.button>Click</CoreComponents.button>|)
      card = rendered_to_string(~H|<CoreComponents.card>body</CoreComponents.card>|)
      header = rendered_to_string(~H|<CoreComponents.header>Title</CoreComponents.header>|)

      list =
        rendered_to_string(
          ~H|<CoreComponents.list><:item title="Foo">Bar</:item></CoreComponents.list>|
        )

      table =
        rendered_to_string(~H"""
        <CoreComponents.table id="users" rows={@rows}>
          <:col :let={row} label="Name">{row.name}</:col>
        </CoreComponents.table>
        """)

      flash = rendered_to_string(~H|<CoreComponents.flash kind={:info} flash={@flash} />|)
      flash_group = rendered_to_string(~H|<CoreComponents.flash_group flash={@empty_flash} />|)
      input = rendered_to_string(~H|<CoreComponents.input name="q" value="" type="text" />|)

      assert icon =~ ~s|data-component="JobyKit.CoreComponents.icon"|
      assert button =~ ~s|data-component="JobyKit.CoreComponents.button"|
      assert card =~ ~s|data-component="JobyKit.CoreComponents.card"|
      assert header =~ ~s|data-component="JobyKit.CoreComponents.header"|
      assert list =~ ~s|data-component="JobyKit.CoreComponents.list"|
      assert table =~ ~s|data-component="JobyKit.CoreComponents.table"|
      assert flash =~ ~s|data-component="JobyKit.CoreComponents.flash"|
      assert flash_group =~ ~s|data-component="JobyKit.CoreComponents.flash_group"|
      assert input =~ ~s|data-component="JobyKit.CoreComponents.input"|
    end
  end

  describe "button" do
    test "renders as <button> by default" do
      assigns = %{}
      html = rendered_to_string(~H|<CoreComponents.button>Send</CoreComponents.button>|)

      assert html =~ "<button"
      assert html =~ "btn"
      assert html =~ "Send"
    end

    test "renders as <a> link when navigate is passed" do
      assigns = %{}

      html =
        rendered_to_string(~H|<CoreComponents.button navigate="/">Home</CoreComponents.button>|)

      assert html =~ "<a"
      assert html =~ ~s|href="/"|
    end

    test "type passes through so form buttons can opt out of submitting" do
      assigns = %{}

      html =
        rendered_to_string(~H|<CoreComponents.button type="button">Cancel</CoreComponents.button>|)

      assert html =~ ~s|type="button"|
    end

    test "omitting type leaves the attribute off (browser default applies)" do
      assigns = %{}
      html = rendered_to_string(~H|<CoreComponents.button>Save</CoreComponents.button>|)

      refute html =~ ~s|type=|
    end

    test "size attr appends btn-sm/btn-lg; md is implicit" do
      assigns = %{}

      sm = rendered_to_string(~H|<CoreComponents.button size="sm">x</CoreComponents.button>|)
      lg = rendered_to_string(~H|<CoreComponents.button size="lg">x</CoreComponents.button>|)
      md = rendered_to_string(~H|<CoreComponents.button size="md">x</CoreComponents.button>|)

      assert sm =~ "btn-sm"
      assert lg =~ "btn-lg"
      refute md =~ "btn-sm"
      refute md =~ "btn-lg"
    end

    test "class is additive — variant default still applies" do
      assigns = %{}

      html =
        rendered_to_string(~H|<CoreComponents.button class="ml-2">x</CoreComponents.button>|)

      assert html =~ "btn-primary"
      assert html =~ "ml-2"
    end
  end

  describe "card" do
    test "renders eyebrow, title, actions slots when provided" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.card>
          <:eyebrow>/design</:eyebrow>
          <:title>Kit</:title>
          body
          <:actions>Open</:actions>
        </CoreComponents.card>
        """)

      assert html =~ "/design"
      assert html =~ "Kit"
      assert html =~ "Open"
      assert html =~ "body"
    end

    test "variant=elevated applies the elevated class set" do
      assigns = %{}

      html =
        rendered_to_string(~H|<CoreComponents.card variant="elevated">body</CoreComponents.card>|)

      assert html =~ "shadow-sm"
    end
  end

  describe "input" do
    test "renders text input with label" do
      assigns = %{}

      html =
        rendered_to_string(
          ~H|<CoreComponents.input name="user[email]" value="" type="text" label="Email" />|
        )

      assert html =~ ~s|name="user[email]"|
      assert html =~ "Email"
      assert html =~ "input"
    end

    test "renders error messages and adds error class when errors present" do
      errors = ["is invalid"]
      assigns = %{errors: errors}

      html =
        rendered_to_string(~H"""
        <CoreComponents.input name="user[email]" value="bad" type="text" errors={@errors} />
        """)

      assert html =~ "is invalid"
      assert html =~ "input-error"
    end

    test "select renders option markup" do
      options = [{"Admin", "admin"}, {"User", "user"}]
      assigns = %{options: options}

      html =
        rendered_to_string(~H"""
        <CoreComponents.input
          name="user[role]"
          value=""
          type="select"
          options={@options}
          prompt="Pick one"
        />
        """)

      assert html =~ "<select"
      assert html =~ "Pick one"
      assert html =~ "Admin"
    end

    test "textarea renders normalized value" do
      assigns = %{}

      html =
        rendered_to_string(
          ~H|<CoreComponents.input name="post[body]" value="hello" type="textarea" />|
        )

      assert html =~ "<textarea"
      assert html =~ "hello"
    end

    test "checkbox renders hidden + visible inputs" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.input name="user[agreed]" value={true} type="checkbox" label="Agreed" />
        """)

      assert html =~ ~s|type="checkbox"|
      assert html =~ ~s|type="hidden"|
      assert html =~ "Agreed"
    end

    test "class lands on the root fieldset, input_class on the control" do
      # 0.3.0 contract: `class` is layout and belongs to the root, like every
      # other kit wrapper. Before, it hit the control, so the field group's
      # own box was unreachable and callers resorted to magic-number nudges
      # on neighbouring elements.
      assigns = %{}

      html =
        rendered_to_string(
          ~H|<CoreComponents.input name="q" value="" type="text" class="col-span-2" input_class="font-mono" />|
        )

      assert root_class(html) =~ "fieldset"
      assert root_class(html) =~ "col-span-2"
      refute root_class(html) =~ "font-mono"

      control = control_class(html)
      assert control =~ "input"
      assert control =~ "font-mono"
      refute control =~ "col-span-2"
    end

    test "the root carries no outer margin" do
      # Every consumer app fought the old hardcoded mb-2 — and couldn't
      # reach it, since class went to the control.
      assigns = %{}
      html = rendered_to_string(~H|<CoreComponents.input name="q" value="" type="text" />|)

      refute root_class(html) =~ ~r/\bm[btlrxy]?-\d/
    end

    test "the root is a semantic fieldset" do
      assigns = %{}
      html = rendered_to_string(~H|<CoreComponents.input name="q" value="" type="text" />|)

      assert html =~ "<fieldset"
    end

    test "width is controlled through the root; the control fills it" do
      assigns = %{}
      html = rendered_to_string(~H|<CoreComponents.input name="q" value="" type="text" class="w-32" />|)

      assert root_class(html) =~ "w-32"
      assert control_class(html) =~ "w-full"
    end

    test "control attributes still pass through to the control, not the fieldset" do
      # :rest carries placeholder/required/readonly/... — putting those on a
      # fieldset would be meaningless markup.
      assigns = %{}

      html =
        rendered_to_string(
          ~H|<CoreComponents.input name="q" value="" type="text" placeholder="Search" required />|
        )

      assert html =~ ~r/<input[^>]*placeholder="Search"/
      assert html =~ ~r/<input[^>]*required/
      refute html =~ ~r/<fieldset[^>]*placeholder/
    end

    for {type, tag} <- [{"text", "input"}, {"select", "select"}, {"textarea", "textarea"}, {"checkbox", "input"}] do
      test "#{type} associates its errors with the control for screen readers" do
        assigns = %{type: unquote(type), tag: unquote(tag)}

        html =
          rendered_to_string(~H"""
          <CoreComponents.input
            name="q"
            id="q"
            value=""
            type={@type}
            options={[a: "a"]}
            errors={["is invalid"]}
          />
          """)

        assert html =~ ~s|aria-invalid="true"|
        assert html =~ ~s|aria-describedby="q-error"|
        # …and the id it points at actually exists in the markup.
        assert html =~ ~s|id="q-error"|
      end
    end

    test "a clean field carries no aria-invalid" do
      assigns = %{}
      html = rendered_to_string(~H|<CoreComponents.input name="q" id="q" value="" type="text" />|)

      refute html =~ "aria-invalid"
      refute html =~ "aria-describedby"
    end

    test "multiple errors share one described-by container" do
      assigns = %{}

      html =
        rendered_to_string(
          ~H|<CoreComponents.input name="q" id="q" value="" type="text" errors={["too short", "is invalid"]} />|
        )

      assert count(html, ~s|id="q-error"|) == 1
      assert html =~ "too short"
      assert html =~ "is invalid"
    end
  end

  describe "translate_error/1" do
    test "interpolates %{key} placeholders" do
      assert CoreComponents.translate_error({"must be at most %{count} chars", count: 10}) ==
               "must be at most 10 chars"
    end

    test "returns plain strings unchanged" do
      assert CoreComponents.translate_error("oh no") == "oh no"
    end

    test "leaves unmatched placeholders alone" do
      assert CoreComponents.translate_error({"value %{x} extra", count: 10}) ==
               "value %{x} extra"
    end

    test "tolerates opts that don't implement String.Chars" do
      # Ecto attaches these to every cast error on an array field. Stringifying
      # opts eagerly (rather than inside the String.replace/4 function form)
      # raises Protocol.UndefinedError on the tuple and 500s the whole form.
      assert CoreComponents.translate_error(
               {"is invalid", [type: {:array, :string}, validation: :cast]}
             ) == "is invalid"
    end

    test "interpolates stringable opts alongside non-stringable ones" do
      assert CoreComponents.translate_error(
               {"expected %{count}", [count: 3, type: {:array, :id}, validation: :cast]}
             ) == "expected 3"
    end

    test "tolerates non-stringable values in a matched placeholder's siblings" do
      # A subset/inclusion error carries a list of atoms plus a real placeholder.
      assert CoreComponents.translate_error(
               {"must be one of %{count}", [count: 2, enum: [:a, :b], validation: :subset]}
             ) == "must be one of 2"
    end
  end

  describe "show/2 and hide/2" do
    test "return Phoenix.LiveView.JS commands" do
      assert %Phoenix.LiveView.JS{} = CoreComponents.show("#foo")
      assert %Phoenix.LiveView.JS{} = CoreComponents.hide("#foo")
    end
  end

  describe "flash id" do
    test "defaults to flash-<kind> when the caller omits id" do
      # `attr :id` puts :id in assigns as nil, so this can't be assign_new/3:
      # the key is always present. Getting it wrong renders the toast with no
      # id and a `hide(to: "#")` dismiss handler, which throws in the browser.
      assigns = %{flash: %{"info" => "Saved."}}

      html = rendered_to_string(~H|<CoreComponents.flash kind={:info} flash={@flash} />|)

      assert html =~ ~s|id="flash-info"|
      assert html =~ ~s|#flash-info|
      refute html =~ ~s|&quot;to&quot;:&quot;#&quot;|
    end

    test "an explicit id still wins" do
      assigns = %{flash: %{"error" => "Nope."}}

      html =
        rendered_to_string(
          ~H|<CoreComponents.flash id="custom-toast" kind={:error} flash={@flash} />|
        )

      assert html =~ ~s|id="custom-toast"|
      assert html =~ ~s|#custom-toast|
    end

    test "every toast flash_group renders carries a usable selector" do
      assigns = %{flash: %{"info" => "Saved.", "error" => "Nope."}}

      html = rendered_to_string(~H|<CoreComponents.flash_group flash={@flash} />|)

      refute html =~ ~s|&quot;to&quot;:&quot;#&quot;|
    end
  end

  describe "flash positioning" do
    test "a flash is an alert, not its own fixed toast container" do
      # Each flash owning a `toast` container meant simultaneous notices
      # stacked at the same fixed position and occluded each other.
      assigns = %{flash: %{"info" => "Saved."}}

      html = rendered_to_string(~H|<CoreComponents.flash kind={:info} flash={@flash} />|)

      assert html =~ "alert"
      refute html =~ "toast"
    end

    test "flash_group supplies exactly one toast container for every notice" do
      assigns = %{flash: %{"info" => "Saved.", "error" => "Nope."}}

      html = rendered_to_string(~H|<CoreComponents.flash_group flash={@flash} />|)

      assert count(html, "toast toast-top toast-end") == 1
      # Both notices still render, now stacked inside that one container.
      assert html =~ "Saved."
      assert html =~ "Nope."
    end

    test "the toast container is click-through; notices are not" do
      assigns = %{flash: %{"info" => "Saved."}}

      html = rendered_to_string(~H|<CoreComponents.flash_group flash={@flash} />|)

      assert html =~ "pointer-events-none"
      assert html =~ "pointer-events-auto"
    end

    test "info is a polite status; error stays assertive" do
      assigns = %{flash: %{"info" => "Saved.", "error" => "Nope."}}

      info = rendered_to_string(~H|<CoreComponents.flash kind={:info} flash={@flash} />|)
      error = rendered_to_string(~H|<CoreComponents.flash kind={:error} flash={@flash} />|)

      assert info =~ ~s|role="status"|
      assert error =~ ~s|role="alert"|
    end

    test "class is declared, so it merges into the root instead of colliding" do
      # Previously `class` arrived via :rest and landed as a second class
      # attribute alongside the hardcoded identity classes.
      assigns = %{flash: %{"info" => "Saved."}}

      flash =
        rendered_to_string(~H|<CoreComponents.flash kind={:info} flash={@flash} class="mt-4" />|)

      group = rendered_to_string(~H|<CoreComponents.flash_group flash={@flash} class="z-10" />|)

      assert root_class(flash) =~ "alert"
      assert root_class(flash) =~ "mt-4"
      assert root_class(group) =~ "toast"
      assert root_class(group) =~ "z-10"
    end
  end

  # Every host form goes through the FormField clause; the raw name/value
  # mode above is the exception, not the rule.
  describe "input with a Phoenix.HTML.FormField" do
    test "derives id, name, and value from the field" do
      assigns = %{field: to_form(%{"email" => "ada@example.com"}, as: :user)[:email]}

      html =
        rendered_to_string(
          ~H|<CoreComponents.input field={@field} type="email" label="Email" />|
        )

      assert html =~ ~s|id="user_email"|
      assert html =~ ~s|name="user[email]"|
      assert html =~ ~s|value="ada@example.com"|
      assert html =~ "Email"
    end

    test "an explicit id wins over the field's" do
      assigns = %{field: to_form(%{"email" => ""}, as: :user)[:email]}

      html = rendered_to_string(~H|<CoreComponents.input field={@field} id="custom" />|)

      assert html =~ ~s|id="custom"|
      # the name still comes from the field
      assert html =~ ~s|name="user[email]"|
    end

    test "renders translated errors once the field has been used" do
      form = to_form(%{"email" => "nope"}, as: :user, errors: [email: {"is invalid", []}])
      assigns = %{field: form[:email]}

      html = rendered_to_string(~H|<CoreComponents.input field={@field} label="Email" />|)

      assert html =~ "is invalid"
      assert html =~ "input-error"
    end

    test "suppresses errors on a field the user has not touched" do
      # used_input?/1 gates this: params carry no "email" key, so the error
      # exists on the changeset but must not render yet.
      form = to_form(%{}, as: :user, errors: [email: {"is invalid", []}])
      assigns = %{field: form[:email]}

      html = rendered_to_string(~H|<CoreComponents.input field={@field} label="Email" />|)

      refute html =~ "is invalid"
      refute html =~ "input-error"
    end

    test "an array-field cast error renders instead of crashing the form" do
      # The P0 fixed in 0.2.3, exercised through the path a host actually
      # takes: Ecto attaches non-String.Chars opts to array-field cast
      # errors, and translate_error/1 used to raise on them mid-render.
      form =
        to_form(%{"tags" => "x"},
          as: :post,
          errors: [tags: {"is invalid", [type: {:array, :string}, validation: :cast]}]
        )

      assigns = %{field: form[:tags]}

      html = rendered_to_string(~H|<CoreComponents.input field={@field} label="Tags" />|)

      assert html =~ "is invalid"
    end

    test "multiple appends [] to the derived name" do
      assigns = %{field: to_form(%{"tags" => ["a"]}, as: :post)[:tags]}

      html =
        rendered_to_string(
          ~H|<CoreComponents.input field={@field} type="select" multiple options={[a: "a"]} />|
        )

      assert html =~ ~s|name="post[tags][]"|
    end
  end

  describe "table with a LiveView stream" do
    setup do
      # stream/4 attaches an after-render hook, so the socket needs a real
      # lifecycle in :private — a bare %Socket{} has only :live_temp.
      socket = %Phoenix.LiveView.Socket{
        private: %{live_temp: %{}, lifecycle: %Phoenix.LiveView.Lifecycle{}}
      }

      socket =
        Phoenix.LiveView.stream(socket, :users, [
          %{id: 1, name: "Ada"},
          %{id: 2, name: "Alan"}
        ])

      %{stream: socket.assigns.streams.users}
    end

    test "marks the tbody for stream updates and derives row dom ids", %{stream: stream} do
      assigns = %{stream: stream}

      html =
        rendered_to_string(~H"""
        <CoreComponents.table id="users" rows={@stream}>
          <:col :let={{_id, user}} label="Name">{user.name}</:col>
        </CoreComponents.table>
        """)

      assert html =~ ~s|phx-update="stream"|
      assert html =~ ~s|id="users"|
      assert html =~ ~s|id="users-1"|
      assert html =~ ~s|id="users-2"|
      assert html =~ "Ada"
      assert html =~ "Alan"
    end

    test "the col slot receives {dom_id, item} tuples, not bare items", %{stream: stream} do
      # Worth pinning: the doc example's `:let={user}` + `user.name` raises
      # under a stream. Callers must destructure or pass row_item.
      assigns = %{stream: stream}

      assert_raise BadMapError, fn ->
        rendered_to_string(~H"""
        <CoreComponents.table id="users" rows={@stream}>
          <:col :let={user} label="Name">{user.name}</:col>
        </CoreComponents.table>
        """)
      end
    end

    test "row_item can unwrap the tuple for callers who prefer bare items", %{stream: stream} do
      assigns = %{stream: stream}

      html =
        rendered_to_string(~H"""
        <CoreComponents.table id="users" rows={@stream} row_item={fn {_id, user} -> user end}>
          <:col :let={user} label="Name">{user.name}</:col>
        </CoreComponents.table>
        """)

      assert html =~ "Ada"
      assert html =~ ~s|id="users-1"|
    end
  end

  describe "table with a plain list" do
    test "omits the stream attribute entirely" do
      assigns = %{rows: [%{id: 1, name: "Ada"}]}

      html =
        rendered_to_string(~H"""
        <CoreComponents.table id="users" rows={@rows}>
          <:col :let={user} label="Name">{user.name}</:col>
        </CoreComponents.table>
        """)

      refute html =~ "phx-update"
      assert html =~ "Ada"
    end

    test "row_click makes the data cells clickable but not the action cell" do
      assigns = %{rows: [%{id: 1, name: "Ada"}]}

      html =
        rendered_to_string(~H"""
        <CoreComponents.table id="users" rows={@rows} row_click={fn row -> "pick-#{row.id}" end}>
          <:col :let={user} label="Name">{user.name}</:col>
          <:action :let={user}>edit-{user.id}</:action>
        </CoreComponents.table>
        """)

      assert html =~ "hover:cursor-pointer"
      assert html =~ "pick-1"
      assert html =~ "edit-1"
      # The action column header is screen-reader only.
      assert html =~ "sr-only"
    end

    test "row_id overrides the generated row identifier" do
      assigns = %{rows: [%{id: 7, name: "Ada"}]}

      html =
        rendered_to_string(~H"""
        <CoreComponents.table id="users" rows={@rows} row_id={fn row -> "u-#{row.id}" end}>
          <:col :let={user} label="Name">{user.name}</:col>
        </CoreComponents.table>
        """)

      assert html =~ ~s|id="u-7"|
    end
  end

  # ------------------------------------------------------------------
  # 0.3.0 de-opinionation. Three consumer apps independently reported
  # routing around baked-in spacing, typography, and missing variants;
  # these lock in the replacements.

  describe "button tones and shapes" do
    test "every declared variant maps to a distinct daisy class" do
      assigns = %{}

      classes =
        for v <- ~w(soft primary neutral ghost danger), into: %{} do
          assigns = Map.put(assigns, :v, v)
          {v, root_class(rendered_to_string(~H|<CoreComponents.button variant={@v}>x</CoreComponents.button>|))}
        end

      assert classes["primary"] =~ "btn-primary"
      assert classes["neutral"] =~ "btn-neutral"
      assert classes["ghost"] =~ "btn-ghost"
      assert classes["danger"] =~ "btn-error"
      assert classes["soft"] =~ "btn-soft"

      # A destructive action must not read the same as a benign one.
      refute classes["danger"] == classes["primary"]
    end

    test "the default is unchanged, and nameable as soft for computed callers" do
      assigns = %{}

      default = root_class(rendered_to_string(~H|<CoreComponents.button>x</CoreComponents.button>|))
      soft = root_class(rendered_to_string(~H|<CoreComponents.button variant="soft">x</CoreComponents.button>|))

      assert default == soft
    end

    test "xs joins the size scale" do
      assigns = %{}
      assert root_class(rendered_to_string(~H|<CoreComponents.button size="xs">x</CoreComponents.button>|)) =~ "btn-xs"
    end

    test "shape gives an icon-only button its square/circle box" do
      assigns = %{}

      circle = root_class(rendered_to_string(~H|<CoreComponents.button shape="circle">x</CoreComponents.button>|))
      square = root_class(rendered_to_string(~H|<CoreComponents.button shape="square">x</CoreComponents.button>|))
      plain = root_class(rendered_to_string(~H|<CoreComponents.button>x</CoreComponents.button>|))

      assert circle =~ "btn-circle"
      assert square =~ "btn-square"
      refute plain =~ "btn-circle"
    end
  end

  describe "eyebrow" do
    test "carries the contract and renders its content" do
      assigns = %{}
      html = rendered_to_string(~H|<CoreComponents.eyebrow>Workspace</CoreComponents.eyebrow>|)

      assert html =~ ~s|data-component="JobyKit.CoreComponents.eyebrow"|
      assert html =~ "Workspace"
      assert html =~ "uppercase"
    end

    test "card and header render their eyebrow slots through it" do
      # The point of extracting this: one definition, not three copies of
      # the same tracking/size/opacity string drifting apart.
      assigns = %{}

      card =
        rendered_to_string(~H"""
        <CoreComponents.card>
          <:eyebrow>From a card</:eyebrow>
          Body
        </CoreComponents.card>
        """)

      header =
        rendered_to_string(~H"""
        <CoreComponents.header>
          Title
          <:eyebrow>From a header</:eyebrow>
        </CoreComponents.header>
        """)

      assert card =~ ~s|data-component="JobyKit.CoreComponents.eyebrow"|
      assert header =~ ~s|data-component="JobyKit.CoreComponents.eyebrow"|
    end
  end

  describe "badge" do
    test "each tone maps to a distinct daisy class" do
      assigns = %{}

      classes =
        for tone <- ~w(neutral ok warn danger info), into: %{} do
          assigns = Map.put(assigns, :tone, tone)
          {tone, root_class(rendered_to_string(~H|<CoreComponents.badge tone={@tone}>x</CoreComponents.badge>|))}
        end

      assert classes["ok"] =~ "badge-success"
      assert classes["warn"] =~ "badge-warning"
      assert classes["danger"] =~ "badge-error"
      assert classes["info"] =~ "badge-info"
      assert classes["neutral"] =~ "badge-neutral"

      assert classes |> Map.values() |> Enum.uniq() |> length() == 5,
             "every tone must be visually distinguishable"
    end

    test "danger means the same thing on a badge as on a button" do
      assigns = %{}
      badge = root_class(rendered_to_string(~H|<CoreComponents.badge tone="danger">x</CoreComponents.badge>|))
      button = root_class(rendered_to_string(~H|<CoreComponents.button variant="danger">x</CoreComponents.button>|))

      assert badge =~ "error"
      assert button =~ "error"
    end

    test "variant and size are enumerated, not leaked through class" do
      assigns = %{}

      assert root_class(rendered_to_string(~H|<CoreComponents.badge variant="outline">x</CoreComponents.badge>|)) =~
               "badge-outline"

      assert root_class(rendered_to_string(~H|<CoreComponents.badge size="lg">x</CoreComponents.badge>|)) =~
               "badge-lg"

      # solid is the absence of a style modifier
      refute root_class(rendered_to_string(~H|<CoreComponents.badge variant="solid">x</CoreComponents.badge>|)) =~
               "badge-soft"
    end
  end

  describe "modal" do
    test "visibility is driven by the server, not the client" do
      assigns = %{}

      closed = rendered_to_string(~H|<CoreComponents.modal id="m">Body</CoreComponents.modal>|)
      open = rendered_to_string(~H|<CoreComponents.modal id="m" show>Body</CoreComponents.modal>|)

      refute root_class(closed) =~ "modal-open"
      assert root_class(open) =~ "modal-open"
      assert open =~ ~s|aria-modal="true"|
    end

    test "one handler covers all three ways out" do
      assigns = %{}

      html =
        rendered_to_string(
          ~H|<CoreComponents.modal id="m" show on_cancel="close">Body</CoreComponents.modal>|
        )

      # close button, backdrop, and Escape
      assert html =~ "modal-backdrop"
      assert html =~ ~s|aria-label="Close"|
      assert html =~ "phx-window-keydown"
      assert html =~ ~s|phx-key="escape"|
      assert count(html, ~s|phx-click="close"|) == 2
    end

    test "a closed dialog does not listen for Escape" do
      # Otherwise every closed modal on the page competes for the key.
      assigns = %{}

      html =
        rendered_to_string(
          ~H|<CoreComponents.modal id="m" on_cancel="close">Body</CoreComponents.modal>|
        )

      refute html =~ "phx-window-keydown=\"close\""
    end

    test "dismissable={false} removes every exit at once" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.modal id="m" show dismissable={false} on_cancel="close">
          Body
        </CoreComponents.modal>
        """)

      refute html =~ "modal-backdrop"
      refute html =~ ~s|aria-label="Close"|
      refute html =~ "phx-window-keydown=\"close\""
    end

    test "the title is announced as the dialog's label" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.modal id="confirm" show>
          <:title>Delete workspace</:title>
          Body
        </CoreComponents.modal>
        """)

      assert html =~ ~s|aria-labelledby="confirm-title"|
      assert html =~ ~s|id="confirm-title"|
    end

    test "static renders in flow so a preview cannot cover the page" do
      # `.modal` is position: fixed — a preview card rendering one would
      # overlay the whole design page.
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.modal id="m" static>
          <:title>In a preview</:title>
          Body
        </CoreComponents.modal>
        """)

      assert root_class(html) =~ "modal-box"
      refute root_class(html) =~ ~r/\bmodal\b(?!-box)/
      refute html =~ "modal-backdrop"
      assert html =~ "In a preview"

      # daisy hides modal-box until a modal-open parent reveals it, so a
      # standalone box renders present-but-invisible without these.
      assert root_class(html) =~ "opacity-100"
      assert root_class(html) =~ "scale-100"
    end
  end

  describe "list" do
    test "the title treatment can be replaced, which is why it went unused" do
      assigns = %{}

      default =
        rendered_to_string(~H"""
        <CoreComponents.list>
          <:item title="Status">Active</:item>
        </CoreComponents.list>
        """)

      custom =
        rendered_to_string(~H"""
        <CoreComponents.list title_class="font-mono text-xs uppercase">
          <:item title="Status">Active</:item>
        </CoreComponents.list>
        """)

      assert default =~ "font-bold"
      assert custom =~ "font-mono text-xs uppercase"
      refute custom =~ "font-bold"
    end
  end

  describe "theme_toggle" do
    test "renders three segments wired to the phx:set-theme event" do
      assigns = %{}
      html = rendered_to_string(~H|<CoreComponents.theme_toggle />|)

      for theme <- ~w(system light dark) do
        assert html =~ ~s|data-phx-theme="#{theme}"|
      end

      assert html =~ "phx:set-theme"
      assert html =~ ~s|data-component="JobyKit.CoreComponents.theme_toggle"|
    end

    test "every segment is a kit button, not raw markup" do
      assigns = %{}
      html = rendered_to_string(~H|<CoreComponents.theme_toggle />|)

      assert count(html, ~s|data-component="JobyKit.CoreComponents.button"|) == 3
    end

    test "icon-only segments carry accessible names" do
      assigns = %{}
      html = rendered_to_string(~H|<CoreComponents.theme_toggle />|)

      assert html =~ ~s|aria-label="Match system theme"|
      assert html =~ ~s|aria-label="Light theme"|
      assert html =~ ~s|aria-label="Dark theme"|
      assert html =~ ~s|role="group"|
    end

    test "active-state classes are literal, so Tailwind can actually generate them" do
      # Building these by interpolating the theme name compiles to a
      # literal `[data-theme=#{theme}]` rule: the segments render but
      # never highlight, because Tailwind scans source as text and cannot
      # evaluate interpolation. Caught in the browser, pinned here.
      assigns = %{}
      html = rendered_to_string(~H|<CoreComponents.theme_toggle />|)

      refute html =~ "\#{", "interpolation leaked into a class name"

      # `&` renders escaped; the browser un-escapes it back to the selector.
      assert html =~ "[[data-theme-source=user][data-theme=light]_&amp;]:text-primary"
      assert html =~ "[[data-theme-source=user][data-theme=dark]_&amp;]:text-primary"
      assert html =~ "[[data-theme-source=system]_&amp;]:text-primary"
    end
  end

  describe "card body opinions" do
    test "body content renders as a direct card-body child so the gap applies" do
      # Previously wrapped in a prose div, which made card-body's gap-2 dead
      # weight and forced callers to hand-add margins between children.
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.card>
          <:title>T</:title>
          <p id="body-child">Body</p>
        </CoreComponents.card>
        """)

      assert html =~ ~r/<div class="card-body[^"]*">.*<p id="body-child"/s
    end

    test "typography is opt-in, not imposed" do
      assigns = %{}

      plain = rendered_to_string(~H|<CoreComponents.card>Body</CoreComponents.card>|)
      prose = rendered_to_string(~H|<CoreComponents.card prose>Body</CoreComponents.card>|)

      refute plain =~ "text-base-content/70"
      assert prose =~ "text-base-content/70"
    end

    test "body_class reaches the card-body element" do
      assigns = %{}
      html = rendered_to_string(~H|<CoreComponents.card body_class="text-base">B</CoreComponents.card>|)

      assert html =~ ~r/class="card-body[^"]*text-base/
    end

    test "actions carry no hardcoded top margin" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.card>
          B
          <:actions>A</:actions>
        </CoreComponents.card>
        """)

      assert html =~ ~s|class="card-actions"|
    end
  end

  describe "header" do
    test "carries no outer spacing" do
      assigns = %{}
      html = rendered_to_string(~H|<CoreComponents.header>Title</CoreComponents.header>|)

      refute root_class(html) =~ "pb-4"
    end

    test "renders the eyebrow slot both consumer apps hand-rolled" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.header>
          Team settings
          <:eyebrow>Workspace</:eyebrow>
        </CoreComponents.header>
        """)

      assert html =~ "Workspace"
      assert html =~ "Team settings"
    end

    test "level picks the heading element so sections don't emit a second h1" do
      assigns = %{}

      assert rendered_to_string(~H|<CoreComponents.header>T</CoreComponents.header>|) =~ "<h1"
      assert rendered_to_string(~H|<CoreComponents.header level="h2">T</CoreComponents.header>|) =~ "<h2"
      refute rendered_to_string(~H|<CoreComponents.header level="h2">T</CoreComponents.header>|) =~ "<h1"
    end

    test "size and title_class control the type scale independently of the tag" do
      assigns = %{}

      page = rendered_to_string(~H|<CoreComponents.header size="page">T</CoreComponents.header>|)
      section = rendered_to_string(~H|<CoreComponents.header size="section">T</CoreComponents.header>|)
      custom = rendered_to_string(~H|<CoreComponents.header title_class="font-display text-4xl">T</CoreComponents.header>|)

      assert page =~ "text-3xl"
      assert section =~ "text-lg"
      assert custom =~ "font-display text-4xl"
      refute custom =~ "text-lg"
    end
  end

  describe "table styling hooks" do
    test "the empty slot replaces the body when there are no rows" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.table id="t" rows={[]}>
          <:col :let={r} label="Name">{r.name}</:col>
          <:empty>No users yet.</:empty>
        </CoreComponents.table>
        """)

      assert html =~ "No users yet."
    end

    test "the empty slot stays hidden when rows exist" do
      assigns = %{rows: [%{name: "Ada"}]}

      html =
        rendered_to_string(~H"""
        <CoreComponents.table id="t" rows={@rows}>
          <:col :let={r} label="Name">{r.name}</:col>
          <:empty>No users yet.</:empty>
        </CoreComponents.table>
        """)

      assert html =~ "Ada"
      refute html =~ "No users yet."
    end

    test "the empty row spans every column, actions included" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.table id="t" rows={[]}>
          <:col :let={r} label="A">{r}</:col>
          <:col :let={r} label="B">{r}</:col>
          <:action :let={r}>{r}</:action>
          <:empty>Nothing.</:empty>
        </CoreComponents.table>
        """)

      assert html =~ ~s|colspan="3"|
    end

    test "zebra striping can be turned off" do
      assigns = %{rows: [%{name: "Ada"}]}

      on =
        rendered_to_string(~H"""
        <CoreComponents.table id="t" rows={@rows}>
          <:col :let={r} label="Name">{r.name}</:col>
        </CoreComponents.table>
        """)

      off =
        rendered_to_string(~H"""
        <CoreComponents.table id="t" rows={@rows} zebra={false}>
          <:col :let={r} label="Name">{r.name}</:col>
        </CoreComponents.table>
        """)

      assert on =~ "table-zebra"
      refute off =~ "table-zebra"
    end

    test "size sets density without leaking daisy class names through class" do
      assigns = %{rows: [%{name: "Ada"}]}

      html =
        rendered_to_string(~H"""
        <CoreComponents.table id="t" rows={@rows} size="xs">
          <:col :let={r} label="Name">{r.name}</:col>
        </CoreComponents.table>
        """)

      assert root_class(html) =~ "table-xs"
    end

    test "the action cell is addressable, so host overrides need not guess with :last-child" do
      assigns = %{rows: [%{id: 1}]}

      html =
        rendered_to_string(~H"""
        <CoreComponents.table id="t" rows={@rows}>
          <:col :let={r} label="A">{r.id}</:col>
          <:action :let={r}>edit-{r.id}</:action>
        </CoreComponents.table>
        """)

      assert html =~ "data-table-actions"
    end
  end

  defp count(haystack, needle), do: length(String.split(haystack, needle)) - 1

  # The class attribute of the first (root) element in the rendered markup.
  defp root_class(html) do
    [_, class] = Regex.run(~r/class="([^"]*)"/, html)
    class
  end

  # The class attribute on the form control itself (input/select/textarea),
  # skipping the wrapper. Matches the element carrying the daisy control class.
  defp control_class(html) do
    [_, class] =
      Regex.run(~r/<(?:input|select|textarea)[^>]*class="([^"]*\b(?:input|select|textarea|checkbox)\b[^"]*)"/, html)

    class
  end
end
