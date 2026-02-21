# frozen_string_literal: true

require_relative "lib/view_component/cache_digest/version"

Gem::Specification.new do |spec|
  spec.name = "view_component-cache_digest"
  spec.version = ViewComponent::CacheDigest::VERSION
  spec.authors = ["Tilde Engineering <engineering@tilde.io>"]
  spec.summary = "Automatic cache digest invalidation for ViewComponent"
  spec.description = <<~DESCRIPTION
    Makes Rails fragment caching (<% cache %>) automatically
    invalidate when ViewComponent source files change.
  DESCRIPTION
  spec.homepage = "https://github.com/tildeio/view_component-cache_digest"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.files = Dir["lib/**/*", "LICENSE.txt", "README.md"]
  spec.require_paths = ["lib"]

  spec.add_dependency "actionview", ">= 7.1"
  spec.add_dependency "view_component", ">= 3.0"
end
