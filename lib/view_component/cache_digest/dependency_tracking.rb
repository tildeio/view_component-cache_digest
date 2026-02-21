# frozen_string_literal: true

module ViewComponent
  module CacheDigest
    module DependencyTracking
      module ERBTracker
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

      module PrismRenderParser
        private

        def render_call_template(node)
          if node.is_a?(Prism::CallNode)
            class_name = prism_constant_name(node.receiver)
            if class_name&.end_with?("Component")
              return ["components/#{class_name.underscore}", false]
            end
          end

          super
        end

        def prism_constant_name(node)
          case node
          when Prism::ConstantReadNode
            node.name.to_s
          when Prism::ConstantPathNode
            parent = node.parent ? "#{prism_constant_name(node.parent)}::" : ""
            "#{parent}#{node.name}"
          end
        end
      end

      module RipperRenderParser
        private

        def parse_render(node)
          args = node.argument_nodes

          if args.length >= 1
            component_path = ripper_component_path(args[0])
            if component_path
              return [partial_to_virtual_path(:partial, component_path)]
            end
          end

          super
        end

        def ripper_component_path(node)
          call_node = case node.type
                      when :method_add_arg then node[0]
                      when :call then node
                      else return
                      end

          return unless call_node.type == :call
          return unless call_node[2].type == :@ident

          class_name = ripper_constant_name(call_node[0])
          "components/#{class_name.underscore}" if class_name&.end_with?("Component")
        end

        def ripper_constant_name(node)
          case node.type
          when :var_ref
            child = node[0]
            child.type == :@const ? child[0] : nil
          when :const_path_ref
            parent_name = ripper_constant_name(node[0])
            child = node[1]
            parent_name && child.type == :@const ? "#{parent_name}::#{child[0]}" : nil
          end
        end
      end
    end
  end
end
