defmodule JobyKit.CoreComponents do
  @moduledoc """
  Core wrapper components shipped by JobyKit. Each component:

    * Carries `data-component="JobyKit.CoreComponents.<name>"` on its
      root element.
    * Declares every prop with `attr` (variant/size enums via `values:`).
    * Accepts `attr :rest, :global` so callers can pass id/class/aria-*/
      phx-* through.
    * Composes daisyUI primitives + theme tokens internally; the `class`
      attr (where exposed) is **additive**, layered on top of the
      wrapper's identity classes.

  Hosts register these against `JobyKit.CoreComponents` in their
  manifest:

      component JobyKit.CoreComponents, :button,
        category: :core,
        daisy_basis: "btn",
        summary: "Standard text button.",
        preview: &MyAppWeb.DesignPreviews.button_preview/1

  And expose them by `import`ing this module into their `core_components`
  / `html_helpers` (or `_web.ex`) so call sites can use the `<.button>`
  form.

  ## Components

    * `flash/1`, `flash_group/1` — toast-style flashes
    * `button/1` — text/link button with variant + size
    * `card/1` — content surface with eyebrow/title/actions slots
    * `header/1` — page or section header
    * `icon/1` — Heroicon span
    * `input/1` — form input (text, email, select, textarea, checkbox…)
    * `list/1` — generic list
    * `table/1` — table with col/action slots, stream-aware

  Plus the JS helpers `show/2`, `hide/2`, and the i18n-free
  `translate_error/1`.
  """

  use Phoenix.Component

  alias Phoenix.LiveView.JS

  # --------------------------------------------------------------- icon

  @doc """
  Renders a [Heroicon](https://heroicons.com).

  Heroicons come in three styles — outline, solid, and mini. Default is
  outline; pass `name="hero-foo-solid"` or `name="hero-foo-mini"` for the
  others. The host must have the Heroicons CSS plugin installed (Phoenix
  ships this by default in `assets/vendor/heroicons.js`).

      <.icon name="hero-x-mark" />
      <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
  """
  attr :name, :string, required: true
  attr :class, :any, default: "size-4"
  attr :rest, :global

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span data-component="JobyKit.CoreComponents.icon" class={[@name, @class]} {@rest} />
    """
  end

  # ------------------------------------------------------------- button

  @doc """
  Standard text button. Renders as `<button>` by default, or `<.link>`
  when `href`/`navigate`/`patch` is passed via `:rest`.

      <.button>Send</.button>
      <.button variant="primary" size="sm">Save</.button>
      <.button navigate={~p"/dashboard"}>Home</.button>
  """
  attr :rest, :global, include: ~w(href navigate patch method download name value disabled)
  attr :class, :any, default: nil
  attr :variant, :string, values: ~w(primary)
  attr :size, :string, values: ~w(sm md lg), default: "md"
  slot :inner_block, required: true

  def button(%{rest: rest} = assigns) do
    variants = %{"primary" => "btn-primary", nil => "btn-primary btn-soft"}
    sizes = %{"sm" => "btn-sm", "md" => nil, "lg" => "btn-lg"}

    assigns =
      assign(assigns, :class_list, [
        "btn",
        Map.fetch!(variants, assigns[:variant]),
        Map.fetch!(sizes, assigns.size),
        assigns.class
      ])

    if rest[:href] || rest[:navigate] || rest[:patch] do
      ~H"""
      <.link
        data-component="JobyKit.CoreComponents.button"
        class={@class_list}
        {@rest}
      >
        {render_slot(@inner_block)}
      </.link>
      """
    else
      ~H"""
      <button data-component="JobyKit.CoreComponents.button" class={@class_list} {@rest}>
        {render_slot(@inner_block)}
      </button>
      """
    end
  end

  # --------------------------------------------------------------- card

  @doc """
  daisyUI card with optional eyebrow, title, and actions slots.

      <.card>
        <:eyebrow>/design</:eyebrow>
        <:title>Kit-curated wrappers</:title>
        Body content goes here.
        <:actions><.button>Open</.button></:actions>
      </.card>
  """
  attr :class, :any, default: nil
  attr :variant, :string, values: ~w(bordered ghost elevated), default: "bordered"
  attr :rest, :global

  slot :eyebrow
  slot :title
  slot :actions
  slot :inner_block, required: true

  def card(assigns) do
    variants = %{
      "bordered" => "border border-base-300 bg-base-100",
      "ghost" => "border border-base-300/40 bg-base-100/60 backdrop-blur",
      "elevated" => "border border-base-300/60 bg-base-100 shadow-sm"
    }

    assigns = assign(assigns, :variant_class, Map.fetch!(variants, assigns.variant))

    ~H"""
    <article
      data-component="JobyKit.CoreComponents.card"
      class={[
        "card transition-shadow duration-200 hover:shadow-md hover:shadow-base-300/40",
        @variant_class,
        @class
      ]}
      {@rest}
    >
      <div class="card-body gap-2">
        <p
          :if={@eyebrow != []}
          class="text-[0.7rem] font-semibold uppercase tracking-[0.18em] text-base-content/55"
        >
          {render_slot(@eyebrow)}
        </p>
        <h3 :if={@title != []} class="card-title text-lg font-semibold leading-tight">
          {render_slot(@title)}
        </h3>
        <div class="text-sm leading-relaxed text-base-content/70">
          {render_slot(@inner_block)}
        </div>
        <div :if={@actions != []} class="card-actions mt-3">
          {render_slot(@actions)}
        </div>
      </div>
    </article>
    """
  end

  # ------------------------------------------------------------- header

  @doc """
  Page or section header with optional subtitle and actions slots.
  """
  attr :class, :any, default: nil
  attr :rest, :global

  slot :inner_block, required: true
  slot :subtitle
  slot :actions

  def header(assigns) do
    ~H"""
    <header
      data-component="JobyKit.CoreComponents.header"
      class={[@actions != [] && "flex items-center justify-between gap-6", "pb-4", @class]}
      {@rest}
    >
      <div>
        <h1 class="text-lg font-semibold leading-8">
          {render_slot(@inner_block)}
        </h1>
        <p :if={@subtitle != []} class="text-sm text-base-content/70">
          {render_slot(@subtitle)}
        </p>
      </div>
      <div :if={@actions != []} class="flex-none">{render_slot(@actions)}</div>
    </header>
    """
  end

  # --------------------------------------------------------------- list

  @doc """
  Generic data list, one row per `:item` slot.

      <.list>
        <:item title="Title">{@post.title}</:item>
        <:item title="Views">{@post.views}</:item>
      </.list>
  """
  attr :class, :any, default: nil
  attr :rest, :global

  slot :item, required: true do
    attr :title, :string, required: true
  end

  def list(assigns) do
    ~H"""
    <ul data-component="JobyKit.CoreComponents.list" class={["list", @class]} {@rest}>
      <li :for={item <- @item} class="list-row">
        <div class="list-col-grow">
          <div class="font-bold">{item.title}</div>
          <div>{render_slot(item)}</div>
        </div>
      </li>
    </ul>
    """
  end

  # -------------------------------------------------------------- table

  @doc """
  Generic table with `:col` slots and an optional `:action` slot. Accepts
  either a regular list or a `Phoenix.LiveView.LiveStream` for `:rows`.

      <.table id="users" rows={@users}>
        <:col :let={user} label="id">{user.id}</:col>
        <:col :let={user} label="username">{user.username}</:col>
      </.table>
  """
  attr :id, :string, required: true
  attr :rows, :list, required: true
  attr :class, :any, default: nil
  attr :row_id, :any, default: nil
  attr :row_click, :any, default: nil
  attr :row_item, :any, default: &Function.identity/1
  attr :rest, :global

  slot :col, required: true do
    attr :label, :string
  end

  slot :action

  def table(assigns) do
    assigns =
      with %{rows: %Phoenix.LiveView.LiveStream{}} <- assigns do
        assign(assigns, row_id: assigns.row_id || fn {id, _item} -> id end)
      end

    ~H"""
    <table
      data-component="JobyKit.CoreComponents.table"
      class={["table table-zebra", @class]}
      {@rest}
    >
      <thead>
        <tr>
          <th :for={col <- @col}>{col[:label]}</th>
          <th :if={@action != []}>
            <span class="sr-only">Actions</span>
          </th>
        </tr>
      </thead>
      <tbody id={@id} phx-update={is_struct(@rows, Phoenix.LiveView.LiveStream) && "stream"}>
        <tr :for={row <- @rows} id={@row_id && @row_id.(row)}>
          <td
            :for={col <- @col}
            phx-click={@row_click && @row_click.(row)}
            class={@row_click && "hover:cursor-pointer"}
          >
            {render_slot(col, @row_item.(row))}
          </td>
          <td :if={@action != []} class="w-0 font-semibold whitespace-nowrap">
            <div class="flex gap-4">
              <%= for action <- @action do %>
                {render_slot(action, @row_item.(row))}
              <% end %>
            </div>
          </td>
        </tr>
      </tbody>
    </table>
    """
  end

  # -------------------------------------------------------------- flash

  @doc """
  Renders a single flash notice. Use inside `flash_group/1` (which the
  layout calls), or directly when you want a one-off toast.

      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} title="Heads up">Something happened</.flash>
  """
  attr :id, :string, default: nil
  attr :flash, :map, default: %{}
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:info, :error], required: true
  attr :rest, :global

  slot :inner_block

  def flash(assigns) do
    # NOT `assign_new/3`: `attr :id` already puts `:id` in assigns (as nil when
    # the caller omits it), so the key is always present and assign_new never
    # fires. That left `@id` nil, which rendered the toast with no id *and*
    # made the dismiss handler `JS.hide(to: "#")` — an invalid selector that
    # throws in the browser on every click.
    assigns = assign(assigns, :id, assigns.id || "flash-#{assigns.kind}")

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      data-component="JobyKit.CoreComponents.flash"
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      role="alert"
      class="toast toast-top toast-end z-50"
      {@rest}
    >
      <div class={[
        "alert w-80 sm:w-96 max-w-80 sm:max-w-96 text-wrap",
        @kind == :info && "alert-info",
        @kind == :error && "alert-error"
      ]}>
        <.icon :if={@kind == :info} name="hero-information-circle" class="size-5 shrink-0" />
        <.icon :if={@kind == :error} name="hero-exclamation-circle" class="size-5 shrink-0" />
        <div>
          <p :if={@title} class="font-semibold">{@title}</p>
          <p>{msg}</p>
        </div>
        <div class="flex-1" />
        <button type="button" class="group self-start cursor-pointer" aria-label="close">
          <.icon name="hero-x-mark" class="size-5 opacity-40 group-hover:opacity-70" />
        </button>
      </div>
    </div>
    """
  end

  @doc """
  Renders the standard flash group: `:info` and `:error` flashes plus
  the disconnected/server-error toasts wired to `phx-disconnected` /
  `phx-connected`. Hosts call this from their root layout.
  """
  attr :id, :string, default: "flash-group"
  attr :flash, :map, required: true
  attr :rest, :global

  def flash_group(assigns) do
    ~H"""
    <div
      id={@id}
      data-component="JobyKit.CoreComponents.flash_group"
      aria-live="polite"
      {@rest}
    >
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title="We can't find the internet"
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        Attempting to reconnect
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title="Something went wrong!"
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        Attempting to reconnect
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  # -------------------------------------------------------------- input

  @doc """
  Renders a form input with label and error messages.

  Pass `field={@form[:foo]}` for the common case; the input pulls id,
  name, value, and errors from the form field. Otherwise pass `name`,
  `value`, `errors` explicitly.

  Supported types: text, email, password, number, search, tel, url,
  date, datetime-local, month, time, week, color, file, hidden,
  checkbox, select, textarea.

      <.input field={@form[:email]} type="email" label="Email" />
      <.input field={@form[:role]} type="select" options={["Admin": "admin"]} />

  ## Class composition

  The wrapper composes the daisyUI input class set internally
  (`input` / `select` / `textarea` / `checkbox`). Passing `class` adds
  utilities **on top** of those — it does not replace them. To toggle
  variants (`size`, error state) the wrapper uses dedicated logic.
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any

  attr :type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file month number password
               search select tel text textarea time url week hidden)

  attr :field, Phoenix.HTML.FormField

  attr :errors, :list, default: []
  attr :checked, :boolean
  attr :prompt, :string, default: nil
  attr :options, :list
  attr :multiple, :boolean, default: false
  attr :class, :any, default: nil

  attr :rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly required rows size step)

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &translate_error/1))
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  def input(%{type: "hidden"} = assigns) do
    ~H"""
    <input
      type="hidden"
      data-component="JobyKit.CoreComponents.input"
      id={@id}
      name={@name}
      value={@value}
      {@rest}
    />
    """
  end

  def input(%{type: "checkbox"} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn ->
        Phoenix.HTML.Form.normalize_value("checkbox", assigns[:value])
      end)

    ~H"""
    <div class="fieldset mb-2" data-component="JobyKit.CoreComponents.input">
      <label for={@id}>
        <input
          type="hidden"
          name={@name}
          value="false"
          disabled={@rest[:disabled]}
          form={@rest[:form]}
        />
        <span class="label">
          <input
            type="checkbox"
            id={@id}
            name={@name}
            value="true"
            checked={@checked}
            class={["checkbox checkbox-sm", @class]}
            {@rest}
          />{@label}
        </span>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <div class="fieldset mb-2" data-component="JobyKit.CoreComponents.input">
      <label for={@id}>
        <span :if={@label} class="label mb-1">{@label}</span>
        <select
          id={@id}
          name={@name}
          class={["w-full select", @errors != [] && "select-error", @class]}
          multiple={@multiple}
          {@rest}
        >
          <option :if={@prompt} value="">{@prompt}</option>
          {Phoenix.HTML.Form.options_for_select(@options, @value)}
        </select>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <div class="fieldset mb-2" data-component="JobyKit.CoreComponents.input">
      <label for={@id}>
        <span :if={@label} class="label mb-1">{@label}</span>
        <textarea
          id={@id}
          name={@name}
          class={["w-full textarea", @errors != [] && "textarea-error", @class]}
          {@rest}
        >{Phoenix.HTML.Form.normalize_value("textarea", @value)}</textarea>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(assigns) do
    ~H"""
    <div class="fieldset mb-2" data-component="JobyKit.CoreComponents.input">
      <label for={@id}>
        <span :if={@label} class="label mb-1">{@label}</span>
        <input
          type={@type}
          name={@name}
          id={@id}
          value={Phoenix.HTML.Form.normalize_value(@type, @value)}
          class={["w-full input", @errors != [] && "input-error", @class]}
          {@rest}
        />
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  attr :rest, :global
  slot :inner_block, required: true

  defp error(assigns) do
    ~H"""
    <p class="mt-1.5 flex gap-2 items-center text-sm text-error" {@rest}>
      <.icon name="hero-exclamation-circle" class="size-5" />
      {render_slot(@inner_block)}
    </p>
    """
  end

  # ----------------------------------------------------------- helpers

  @doc """
  JS command for fading an element in.
  """
  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      time: 300,
      transition:
        {"transition-all ease-out duration-300",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
  end

  @doc """
  JS command for fading an element out.
  """
  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition:
        {"transition-all ease-in duration-200", "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
  end

  @doc """
  Translate an Ecto error tuple `{msg, opts}` into a plain string by
  interpolating `%{key}` placeholders. No Gettext dependency — hosts
  that need i18n should override this function (or wrap `<.input>`).
  """
  def translate_error({msg, opts}) when is_binary(msg) and is_list(opts) do
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", to_string(value))
    end)
  end

  def translate_error(msg) when is_binary(msg), do: msg
end
