module RubyRedInk
  class RuntimeObject
    # RuntimeObjects can be included in the main story as a hierarchy
    # usually parents are container objectsd
    attr_accessor :parent, :own_debug_metadata, :path, :original_object

    def debug_metadata
      if @own_debug_metadata.nil?
        if !parent.nil?
          return parent.debug_metadata || DebugMetadata.new
        end
      end

      return @own_debug_metadata
    end

    def indentation_string(indentation = 0)
      " " * indentation
    end

    def debug_line_number_of_path(path)
      return nil if path.nil?

      # Try to get a line number from debug metadata
      root = self.root_content_container

      if !root.nil?
        target_content = root.content_at_path(path).object
        if !target_content.nil?
          target_debug_metadata = target_content.debug_metadata
          if !target_debug_metadata.nil?
            target_debug_metadata.start_line_number
          end
        end
      end
    end

    def path
      if @path.nil?
        if parent.nil?
          @path = Path.new("")
        else
          # Maintain a stack so that the order of the components is reversed
          # when they're added to the Path. We're iterating up from the
          # leaves/children to the root
          components = []

          child = self
          container = child.parent

          while !container.nil?
            if child.is_a?(Container) && child.valid_name?
              components << Path::Component.new(name: child.name)
            else
              components << Path::Component.new(index: container.content.index(child))
            end

            child = container
            container = container.parent
          end

          @path = Path.new(components.reverse)
        end
      end

      return @path
    end

    def resolve_path(path)
      if path.relaive?
        nearest_container = self

        if !nearest_container.is_a?(Container)
          nearest_container = self.parent
          path = path.tail
        end

        return nearest_container.content_at_path(path)
      else
        return this.root_content_container.content_at_path(path)
      end
    end

    def convert_path_to_relative(global_path)
      # 1. Find last shared ancestor
      # 2. Drill up using '..' style (actually represented as "^")
      # 3. Re-build downward chain from common ancestor

      own_path = self.path

      min_path_length = [global_path.length, own_path.length].min
      last_shared_path_comp_index = -1
      (0..min_path_length).each do |i|
        own_component = own_path.components[i]
        other_component = global_path.components[i]

        if own_component == other_component
          last_shared_path_comp_index = i
        else
          break
        end
      end

      # No shared path components, so just use global path
      if last_shared_path_comp_index == -1
        return global_path
      end

      number_of_upwards_moves = (own_path.length - 1) - last_shared_path_comp_index
      new_path_components = []

      (0..number_of_upwards_moves).each do |i|
        new_path_components << Path::Component.parent_component
      end

      (last_shared_path_comp_index + 1..global_path.length).each do |i|
        new_path_components << global_path.components[i]
      end

      return Path.new(new_path_components, true)
    end

    # Find the most compact representation for a path,
    # whether relative or global
    def compact_path_string(other_path)
      if other_path.relative?
        relative_path_string = other_path.components_string
        global_path_string = self.path.path_by_appending_path(other_path).components_string
      else
        relative_path = convert_path_to_relative(other_path)
        relative_path_string = relative_path.components_string
        global_path_string = other_path.components_string
      end

      if relative_path_string.length < global_path_string.length
        return relative_path_string
      else
        return global_path_string
      end
    end

    def root_content_container
      ancestor = self
      while !ancestor.parent.nil?
        ancestor = ancestor.parent
      end

      return ancestor
    end

    def copy
      raise NotImplementedError, "#{self.class} doesn't support copying"
    end
  end
end