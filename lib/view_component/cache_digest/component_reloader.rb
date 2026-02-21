# frozen_string_literal: true

module ViewComponent
  module CacheDigest
    # Watches component directories for file changes and clears the digest
    # cache, mirroring what ActionView::CacheExpiry::ViewReloader does.
    class ComponentReloader
      def initialize(watcher:, paths:)
        @watcher = watcher.new([], paths) do
          ActionView::LookupContext::DetailsKey.clear
        end
      end

      def updated?
        @watcher.updated?
      end

      def execute
        @watcher.execute
      end
    end
  end
end
