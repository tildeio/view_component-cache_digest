# frozen_string_literal: true

module ViewComponent
  module CacheDigest
    class Railtie < Rails::Railtie
      config.view_component.component_paths = ["app/components"]

      config.after_initialize do |app|
        next if ENV["DISABLE_VIEW_COMPONENT_CACHE_DIGEST"]

        component_paths = CacheDigest.component_paths = app.config.view_component.component_paths

        config.after_initialize do
          require "action_view/dependency_tracker"
          require_relative "dependency_tracking"

          if defined?(ActionView::DependencyTracker::ERBTracker)
            ActionView::DependencyTracker::ERBTracker.prepend(DependencyTracking::ERBTracker)
          end

          if defined?(ActionView::RenderParser::PrismRenderParser)
            ActionView::RenderParser::PrismRenderParser.prepend(DependencyTracking::PrismRenderParser)
          end
          
          if defined?(ActionView::RenderParser::RipperRenderParser)
            ActionView::RenderParser::RipperRenderParser.prepend(DependencyTracking::RipperRenderParser)
          end
          
          if defined?(ActionView::RenderParser) && ActionView::RenderParser.is_a?(Class)
            ActionView::RenderParser.prepend(DependencyTracking::PrismRenderParser)
          end
        end

        ActiveSupport.on_load(:action_controller) do
          require_relative "resolver"
          append_view_path(ViewComponent::CacheDigest::Resolver.new)
        end

        if app.config.reloading_enabled?
          require_relative "component_reloader"

          component_reloader = ComponentReloader.new(
            watcher: app.config.file_watcher,
            paths: component_paths.map { |p| app.root.join(p).to_s },
          )

          app.reloaders << component_reloader

          app.reloader.to_run do
            require_unload_lock!
            component_reloader.execute
          end
        end
      end
    end
  end
end
