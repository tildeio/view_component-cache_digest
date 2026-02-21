# frozen_string_literal: true

module ViewComponent
  module CacheDigest
    class << self
      attr_accessor :component_paths
    end
  end
end

require_relative "cache_digest/version"
require_relative "cache_digest/railtie"
