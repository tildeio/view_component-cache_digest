# frozen_string_literal: true

module ViewComponent
  module CacheDigest
    module DependencyTracking
      COMPONENT_RENDER = /\A\s*\(?\s*((?:[A-Z]\w*::)*[A-Z]\w*Component)\b/

      private

      def add_dependencies(render_dependencies, arguments, pattern)
        if (match = arguments.match(COMPONENT_RENDER))
          render_dependencies << "components/#{match[1].underscore}"
        else
          super
        end
      end
    end
  end
end
