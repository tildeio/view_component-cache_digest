# ViewComponent::CacheDigest

Working proof-of-concept solution to [#234](https://github.com/ViewComponent/view_component/issues/234).

Automatic fragment cache invalidation for [ViewComponent](https://viewcomponent.org/).

```erb
<% cache @post do %>
  <%= render PostCardComponent.new(post: @post) %>
<% end %>
```

Without this gem, editing `PostCardComponent`'s template, Ruby class, or
sidecar files does not invalidate the cache.

With this gem, the fragment cache is automatically invalidated when any of
those related files are edited, using the same digest tree mechanism Rails
uses for partials.

## Installation

```ruby
# Gemfile
gem "view_component-cache_digest", github: "tildeio/view_component-cache_digest"
```

That's it. The Railtie wires everything up at boot.

By default, it assumes all your components are located in `app/components`. If
that is not true for your app, you will have to adjust the following config,
such as `config.view_component.component_paths << "lib/view_components"`.

## How It Works

Rails computes a digest for each template from its source (the erb content) and
its dependencies (and templates/partials it rendered). This digest is added to
the cache key for all `<% cache %>` helper calls within the template, so that
when the template (or its dependencies) changes, the cache misses and the block
re-renders.

This fails for ViewComponent because:

1. **Discovery** — Rails doesn't recognize the `render SomeComponent.new(...)`
   syntax when scanning the template for implicit dependencies.

2. **Resolution** — even if the dependency is discovered, component templates
   live outside the view paths so the Digestor can't locate them.

This gem fixes both problems.

### Discovery – `ViewComponent::CacheDigest::DependencyTracking`

Rails' `ERBTracker` works statically against template source, and does a simple
Regex split on `\brender\b`. So a template like:

```erb
Hello! <%= render FooComponent.new(...) %>
<%= render partial: "bar", locals: { ... } %>
```

...gets split into the following chunks...

```
Hello! <%= (initial chunk, discarded)
```

```
FooComponent.new(...) %>\n<%=
```

```
partial: "bar", locals: { ... } %>
```

It infers the implicit template dependencies based on the string immediately
after the match. This works for the "built-in" Rails render syntax but it does
not recognize the view component syntax, or "renderables" in general.

We prepend the `ViewComponent::CacheDigest::DependencyTracking` module to
`ERBTracker` to override its `#add_dependencies` method, which gets called once
per each matched fragment. If it matches `<%= render ClassEndingInComponent...`
it'll report `components/class_ending_in_component` as a dependency for that
template, otherwise it'll call `super` and let Rails do its thing.

| Fragment after `render`          | Match? | Dependency                        |
| -------------------------------- | ------ | --------------------------------- |
| `(PostCardComponent.new(post:))` | Yes    | `components/post_card_component`  |
| `(Admin::CardComponent.build)`   | Yes    | `components/admin/card_component` |
| `("posts/post")`                 | No     | Falls through to `super`          |
| `(@post)`                        | No     | Falls through to `super`          |

Note: sometimes, the call is too dynamic for the dependency tracker's static
heuristics to work, e.g. if you construct the component in Ruby code and then
does `<%= render @my_component %>`. (This can happen in Rails too – for example
`<%= render @foo %>` where `foo` does not match the name of the model like
Rails expect.)

For these circumstances, Rails provides the `# Template Dependency: ...` as a
manual escape hatch:

```erb
<%
  if params[:c] == "foo"
    # Template Dependency: components/foo
    component = FooComponent
  else
    # Template Dependency: components/foo
    component = BarComponent
  end
%>
<%= render component %>
```

```erb
<%# Template Dependency: foo/_bar %>
<%= render @foo_bar %>
```

### Resolution – `ViewComponent::CacheDigest::Resolver`

The code above lets us express the a template's dependency on a view component
by added `components/foo` as a dependency (implicit or explicit), but there is
a second problem – with that path, Rails expects to find a template at
`app/views/components/_foo.html.erb`, but that's not where our templates go.

Another issue is that a component's dependency is not just the template file
itself, but also its associated Ruby class and other sidecar files. If any of
those source file changes, the template can render differently.

`ViewComponent::CacheDigest::Resolver` is custom `ActionView::Resolver` that
synthesizes these virtual paths (`components/foo`) into a erb template that
expresses all these dependencies correctly.

When the Digestor asks for `components/post_card_component`, the Resolver
returns a synthetic template like:

```erb
<% raise ViewComponent::CacheDigest::TemplateError, "..." %>
<%# Resolved Dependency: app/components/post_card_component.rb 8a3f2b... %>
<%# Resolved Dependency: app/components/post_card_component/en.yml a1b2c3... %>
<%# Template Dependency: components/card_component %>
<div class="post-card">
  <%= render AvatarComponent.new(user: @post.author) %>
  <%= render "shared/timestamp", time: @post.created_at %>
</div>
```

This template is **never compiled or rendered** — the Digestor only reads its
`.source` string for the purpose of computing a cache digest.

Each section serves a purpose:

- **`raise` guard** — safety net if accidentally rendered

- **`Resolved Dependency:` lines** — content hashes of the `.rb` file
  and sidecar files; alter the source hash so any change to these files
  changes the digest

- **`Template Dependency:` lines** — extracted `# Template Dependency:`
  comments from the component `.rb` file; resolved as tree nodes

- **The actual template source** — included verbatim so `ERBTracker` can
  discover sub-component and partial dependencies

## What Invalidates the Cache

| Change                               | Effect                                                     |
| ------------------------------------ | ---------------------------------------------------------- |
| Component `.html.erb` edited         | Synthesized source changes (ERB body)                      |
| Component `.rb` edited               | Synthesized source changes (`Resolved Dependency:` digest) |
| Sidecar file (e.g. i18n YAML) edited | Synthesized source changes (`Resolved Dependency:` digest) |
| Child component template edited      | Child digest cascades up                                   |
| Child component `.rb` edited         | Child's `Resolved Dependency:` digest changes, cascades up |
| Plain Rails partial edited           | Standard Rails digest cascade (works with or without gem)  |

## Escape Hatch

For dependencies not statically visible as ERB `<%= render %>` (inheritance,
inline templates, `call` method, dynamic renders), use `# Template Dependency`
in the `.rb` or `.erb` files:

```ruby
# Template Dependency: components/card_component
class PostCardComponent < CardComponent
  # ...
end
```

## Known Limitations

**Ruby files are not scanned by `ERBTracker`** so inline templates and `call`
method components do not get their implicit dependencies synthesized, and must
rely on explicit `# Template Dependency: ` magic comments.

**Inheritance/superclass are not tracked** as it would require loading the Ruby
class/evaluating the component Ruby file and can be hairy/unreliable. Use the
magic comment escape hatch.
