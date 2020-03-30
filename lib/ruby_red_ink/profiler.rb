module RubyRedInk
  # Simple ink profiler that logs every instruction in the story and counts frequency and timing.
  # To use:
  #
  #   profiler = story.start_profiling!
  #
  #   (play your story for a bit)
  #
  #   report = profiler.report;
  #
  #   story.end_profiling!;
  class Profiler
    # The root node in the hierarchical tree of recorded ink timings
    attr_accessor :root_node, :continue_watch, :step_watch, :snapshot_watch,
      :number_of_continues,
      :continue_total, :step_total, :snapshot_total, :current_step_stack,
      :current_step_details, :step_details

    def initialize
      self.root_node = ProfileNode.new
      self.continue_watch = Stopwatch.new
      self.step_watch = Stopwatch.new
      self.snapshot_watch = Stopwatch.new
      self.step_details = []
      self.number_of_continues = 0
    end

    # Generate a printable report based on the data recorded during profiling
    def report
      <<~STR
      #{number_of_continues} CONTINUES / LINES:
      TOTAL TIME: #{self.class.format_milliseconds(continue_total)}
      SNAPSHOTTING: #{self.class.format_milliseconds(snapshot_total)}
      OTHER: #{self.class.format_milliseconds(continue_total - (step_total + snapshot_total))}
      #{root_node.as_string}
      STR
    end

    def pre_continue!
      continue_watch.restart!
    end

    def post_continue!
      continue_watch.stop!
      continue_total += continue_watch.elapsed_milliseconds
      number_of_continues += 1
    end

    def pre_step!
      current_step_stack = nil
      step_watch.restart!
    end

    def step!(callstack)
      step_watch.stop!

      stack = []
      callstack.elements.each do |element|
        stack_element_name = ""
        if !element.current_pointer.null_pointer?
          path = element.current_pointer.path
          path.components.each do |component|
            if !component.is_index?
              stack_element_name = component.name
              break
            end
          end
        end

        stack << stack_element_name
      end

      current_step_stack = stack

      current_object = callstack.current_element.current_pointer.resolve!

      if ControlCommands::COMMANDS.has_key?(element)
        step_type = "#{element} CC"
      else
        step_type = current_object.class.to_s
      end

      current_step_details = StepDetails.new(
        type: step_type,
        object: current_object
      )

      step_watch.start!
    end

    def post_step!
      step_watch.stop!
      duration = step_watch.elapsed_milliseconds
      step_total += duration

      root_node.add_sample(current_step_stack, duration)

      current_step_details.time = duration
      step_details << current_step_details
    end

    # Generate a printable report specifying the average and maximum times spent
    # stepping over different internal ink instruction types.
    # This report type is primarily used to profile the ink engine itself rather
    # than your own specific ink.
    def step_length_report
      report = StringIO.new

      report << "TOTAL:#{root_node.total_milliseconds}ms\n"

      grouped_step_times = step_details.group_by{|x| x.type }

      average_step_times = grouped_step_times.map do |type, details|
        average = details.sum{|x| x.time }/details.size
        [type, average]
      end.sort_by{|type, average| average}.reverse.map{|type, average| "#{type}: #{average}ms" }

      report << "AVERAGE STEP TIMES: #{average_step_times.join(", ")}\n"

      accumulated_step_times = grouped_step_times.map do |type, details|
        sum = details.sum{|x| x.time }
        ["#{type} (x#{details.size})", sum]
      end.sort_by{|type, sum| sum}.reverse.map{|type, sum| "#{type}: #{sum}ms" }

      report << "ACCUMULATED STEP TIMES: #{accumulated_step_times.join(", ")}\n"

      report.rewind
      report.read
    end

    # Create a large log of all the internal instructions that were evaluated while
    # profiling was active. Log is in a tab-separated format, for easing loading into
    # a spreadsheet
    def mega_log
      report = StringIO.new
      report << "Step type\tDescription\tPath\tTime\n"

      step_details.each do |step|
        report << "#{step.type}\t#{step.object.as_string}\t#{step.object.path.as_string}\t#{step.time.to_s}\n"
      end

      report.rewind
      report.read
    end

    def pre_snapshot!
      snapshot_watch.restart!
    end

    def post_snapshot!
      snapshot_watch.stop!
      snapshot_total += snapshot_watch.elapsed_milliseconds
    end

    def self.format_milliseconds(milliseconds)
      if milliseconds > 1_000
        "#{(milliseconds/1_000.0).round(2)} s"
      else
        "#{(milliseconds).round(3)} ms"
      end
    end

    # Node used in the hierarchical tree of timings used by the Profiler.
    # Each node corresponds to a single line viewable in a UI-based representation.
    class ProfileNode
      attr_accessor :key, :nodes, :total_milliseconds, :total_sample_count,
        :self_sample_count, :self_milliseconds

      def has_children?
        !nodes.nil? && nodes.size > 0
      end

      def initialize
        total_sample_count = 0
        total_milliseconds = 0
        self_sample_count = 0
        self_milliseconds = 0
      end

      def initialize(key)
        self.key = key
      end

      def add_sample(stack, duration)
        add_sample(stack, -1, duration)
      end

      def add_sample(stack, stack_index, duration)
        total_milliseconds += 1
        total_milliseconds += duration

        if stack_index == (stack.size - 1)
          self_sample_count += 1
          self_milliseconds += duration
        end

        if stack_index < stack.size
          add_sample_to_node(stack, stack_index + 1, duration)
        end
      end

      def add_sample_to_node(stack, stack_index, duration)
        node_key = stack[stack_index]
        nodes ||= {node_key => ProfileNode.new(node_key)}

        node[node_key].add_sample(stack, stack_index, duration)
      end

      def print_hierarchy(io, indent)
        self.class.pad(io, indent)

        io << "#{key}: #{own_report}\n"

        return if nodes.nil?

        nodes.sort_by{|k,v| v.total_milliseconds }.reverse.each do |key, node|
          node.print_hierarchy(io, indent + 1)
        end
      end

      # Generates a string giving timing information for this single node, including
      # total milliseconds spent on the piece of ink, the time spent within itself
      # (v.s. spent in children), as well as the number of samples (instruction steps)
      # recorded for both too.
      def own_report
        report = StringIO.new

        report << "total #{Profiler.format_milliseconds(total_milliseconds)}"
        report << ", self #{Profiler.format_milliseconds(self_milliseconds)}"
        report << " (#{self_sample_count} self samples, #{total_sample_count} total)"

        report.rewind
        report.read
      end

      def as_string
        report = StringIO.new
        print_hierarchy(report, 0)
        report.rewind
        report.read
      end

      def self.pad(io, indent)
        io << " " * indent
      end
    end

    class Stopwatch
      attr_accessor :start_time, :stop_time, :elapsed_milliseconds

      def initialize
        elapsed_milliseconds = 0
      end

      def start!
        stop_time = nil
        start_time = Time.now.utc
      end

      def reset!
        elapsed_milliseconds = 0
      end

      def restart!
        reset!
        start!
      end

      def stop!
        stop_time = Time.now.utc
        elapsed_milliseconds += elapsed_from_start_to_stop
      end

      def elapsed_milliseconds
        return -1 if start_time.nil?
        if @elapsed_milliseconds == 0 && stop_time.nil?
          return elapsed_from_start_to_stop
        else
          @elapsed_milliseconds
        end
      end

      def elapsed_from_start_to_stop
        ((stop_time || Time.now.utc).to_r - start_time.to_r)) * 1000.0
      end
    end
  end
end