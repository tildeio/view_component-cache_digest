# frozen_string_literal: true

require_relative "dependency_tracking"
require_relative "resolver"

module ViewComponent
  module CacheDigest
    class Railtie < Rails::Railtie
      # Initialize before application config runs so users can
      # do config.view_component.component_paths << "lib/components"
      config.view_component.component_paths = ["app/components"]

      initializer "view_component_cache_digest.configure", after: "view_component.set_configs" do |app|
        next if ENV["DISABLE_VIEW_COMPONENT_CACHE_DIGEST"]

        CacheDigest.component_paths = app.config.view_component.component_paths

        require "action_view/dependency_tracker"

        ActionView::DependencyTracker::ERBTracker.prepend(
          ViewComponent::CacheDigest::DependencyTracking
        )

        ActiveSupport.on_load(:action_controller) do
          append_view_path(ViewComponent::CacheDigest::Resolver.new)
        end
      end
    end
  end
end
