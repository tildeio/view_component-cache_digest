# frozen_string_literal: true

require "digest/sha2"

module ViewComponent
  module CacheDigest
    class TemplateError < StandardError; end

    class Resolver < ActionView::Resolver
      def _find_all(name, prefix, partial, details, key, locals)
        return [] unless prefix&.start_with?("components")

        relative = (prefix == "components") ? name : "#{prefix.delete_prefix("components/")}/#{name}"
        rb_path, base_path = find_component(relative)

        return [] unless rb_path

        requested = key || ActionView::TemplateDetails::Requested.new(**details)
        template_path = find_matching_template(base_path, requested)

        return [] unless template_path

        source = synthesize_template(rb_path, base_path, name, prefix, partial, template_path)
        vpath = ActionView::TemplatePath.virtual(name, prefix, partial)
        format = path_parser.parse(File.basename(template_path)).details.format

        [ActionView::Template.new(
          source,
          "view_component_digest:#{relative}",
          ActionView::Template.handler_for_extension(:erb),
          locals: [],
          format: format,
          virtual_path: vpath
        )]
      end

      private

      def find_component(relative)
        CacheDigest.component_paths.each do |dir|
          base_path = Rails.root.join(dir, relative)
          rb_path = "#{base_path}.rb"
          return [rb_path, base_path] if File.exist?(rb_path)
        end
        nil
      end

      def path_parser
        @path_parser ||= ActionView::Resolver::PathParser.new
      end

      def find_matching_template(base_path, requested)
        candidates = template_files(base_path)

        matched = candidates.select do |path|
          path_parser.parse(File.basename(path)).details.matches?(requested)
        end

        if matched.length > 1
          matched.sort_by! do |path|
            path_parser.parse(File.basename(path)).details.sort_key_for(requested)
          end
        end

        matched.first
      end

      def synthesize_template(rb_path, base_path, name, prefix, partial, template_path)
        vpath = ActionView::TemplatePath.virtual(name, prefix, partial)
        parts = []

        parts << %(<% raise ViewComponent::CacheDigest::TemplateError, "#{vpath}" %>)

        resolved_dependency_files(rb_path, base_path).each do |path|
          digest = Digest::SHA256.file(path).hexdigest
          short = path.delete_prefix("#{Rails.root}/")
          parts << "<%# Resolved Dependency: #{short} #{digest} %>"
        end

        rb_source = File.read(rb_path)
        rb_source.scan(/# Template Dependency: (\S+)/).each do |dep|
          parts << "<%# Template Dependency: #{dep[0]} %>"
        end

        parts << File.read(template_path)

        parts.join("\n")
      end

      def template_handler_extensions
        @template_handler_extensions ||=
          ActionView::Template.template_handler_extensions.map { |e| ".#{e}" }.to_set
      end

      def template_files(base_path)
        extensions = ActionView::Template.template_handler_extensions.join(",")
        component_name = File.basename(base_path)
        directory = File.dirname(base_path)

        files = Dir["#{directory}/#{component_name}.*{#{extensions}}"]
        files.concat Dir["#{directory}/#{component_name}/#{component_name}.*{#{extensions}}"]
        files
      end

      def resolved_dependency_files(rb_path, base_path)
        component_name = File.basename(base_path)
        directory = File.dirname(base_path)
        sidecar_dir = "#{directory}/#{component_name}"

        files = [rb_path]
        if Dir.exist?(sidecar_dir)
          Dir["#{sidecar_dir}/**/*"].each do |f|
            next unless File.file?(f)
            next if template_handler_extensions.include?(File.extname(f))

            files << f
          end
        end

        files
      end
    end
  end
end
