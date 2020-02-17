module RubyRedInk
  module Path
    PARENT = :PARENT
    RELATIVE_PATH = :RELATIVE_PATH
    ROOT_PATH = :ROOT_PATH

    def self.append_path_string(parent_string, identifier)
      if parent_string == ""
        identifier.to_s
      else
        "#{parent_string}.#{identifier}"
      end
    end

    def self.parse(path_string)
      path_tree = {}
      if path_string.start_with?(".")
        start = RELATIVE_PATH
      else
        start = ROOT_PATH
      end

      path_tree[start] = {}

      elements = path_string.split(".")

      current_pointer = path_tree[start]
      elements.each do |element|
        next if element == ""
        new_path = {}
        if element == "^"
          current_pointer[PARENT] = new_path
        elsif element.start_with?(/\d/)
          current_pointer[Integer(element)] = new_path
        else
          current_pointer[element] = new_path
        end

        current_pointer = new_path
      end

      path_tree
    end

    def self.jump_up_level(path_string)
      elements = path_string.split('.')
      elements.pop
      elements.join('.')
    end

    def self.travel(path_tree, root, current_container, current_pointer)
      label, rest_of_tree = path_tree.first

      if rest_of_tree.empty?
        return current_pointer.all_elements[label]
      end

      if label == ROOT_PATH
        current_pointer = root
      elsif label == RELATIVE_PATH
        current_pointer = current_container
      elsif label == PARENT
        current_pointer = current_container
        current_container = current_pointer.parent
      else
        current_pointer = current_pointer.all_elements[label]
      end

      travel(rest_of_tree, root, current_container, current_pointer)
    end

    def self.navigate(root, current_container, path_string)
      path_tree = parse(path_string)

      current_pointer = nil
      travel(path_tree, root, current_container, current_pointer)
    end

    def self.closest_container_travel(path_tree, root, current_container, current_pointer)
      label, rest_of_tree = path_tree.first

      if rest_of_tree.empty?
        target = current_pointer.all_elements[label]
        if target.is_a?(Container)
          return target
        else
          return current_pointer
        end
      end

      if label == ROOT_PATH
        current_pointer = root
      elsif label == RELATIVE_PATH
        current_pointer = current_container
      elsif label == PARENT
        current_pointer = current_container
        current_container = current_pointer.parent
      else
        current_pointer = current_pointer.all_elements[label]
      end

      closest_container_travel(rest_of_tree, root, current_container, current_pointer)
    end

    def self.closest_container(root, current_container, path_string)
      path_tree = parse(path_string)

      current_pointer = nil
      closest_container_travel(path_tree, root, current_container, current_pointer)
    end
  end
end