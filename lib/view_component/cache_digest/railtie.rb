# frozen_string_literal: true

require_relative "dependency_tracking"
require_relative "resolver"

module ViewComponent
  module CacheDigest
    class Railtie < Rails::Railtie
      config.view_component.component_paths = ["app/components"]

      config.after_initialize do |app|
        next if ENV["DISABLE_VIEW_COMPONENT_CACHE_DIGEST"]

        CacheDigest.component_paths = app.config.view_component.component_paths

        ActiveSupport.on_load(:action_controller) do
          append_view_path(ViewComponent::CacheDigest::Resolver.new)
        end

        config.after_initialize do
          require "action_view/dependency_tracker"

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
      end
    end
  end
end
