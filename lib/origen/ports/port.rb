module Origen
  module Ports
    class Port
      include Netlist::Connectable

      attr_reader :size
      attr_reader :parent
      attr_reader :id

      alias_method :name, :id
      alias_method :owner, :parent

      def initialize(parent, id, options = {})
        @size = options[:size] || 1
        @parent = parent
        @id = id
        @bit_names = {}.with_indifferent_access
      end

      def path
        if parent.path.empty?
          id.to_s
        else
          "#{parent.path}.#{id}"
        end
      end

      def bits(index, name, options = {})
        if @defining
          @bit_names[name] = index
        else
          fail 'Cannot add additional port bits once the port definition is complete'
        end
      end

      def drive(value = nil, options = {})
        value, options = nil, value if value.is_a?(Hash)
        if options[:index]
          if options[:index].is_a?(Fixnum)
            drive_values[options[:index]] = value ? value[0] : nil
          else
            options[:index].to_a.each do |i|
              drive_values[i] = value ? value[i] : nil
            end
          end
        else
          size.times do |i|
            drive_values[i] = value ? value[i] : nil
          end
        end
        @drive_value = value
      end

      def drive_values
        @drive_values ||= Array.new(size)
      end

      def to_section
        Section.new(self, (size - 1)..0)
      end

      def method_missing(method, *args, &block)
        if @bit_names.key?(method)
          Section.new(self, @bit_names[method])
        elsif BitCollection.instance_methods.include?(method)
          to_bc.send(method, *args, &block)
        else
          super
        end
      end

      def respond_to?(*args)
        @bit_names.key?(args.first) || super(*args) ||
          BitCollection.instance_methods.include?(args.first)
      end

      def [](val)
        Section.new(self, val)
      end

      def to_bc
        to_section.to_bc
      end

      private

      def defining
        @defining = true
        yield
        @defining = false
      end
    end
  end
end
