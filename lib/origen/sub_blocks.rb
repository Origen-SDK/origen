module Origen
  module SubBlocks
    # This will be called whenever an object that includes this module
    # is instantiated
    #
    # @api private
    def init_sub_blocks(*args)
      options = args.find { |a| a.is_a?(Hash) }
      if options
        # Using reg_base_address for storage to avoid class with the original Origen base
        # address API, but will accept any of these
        @reg_base_address = options.delete(:reg_base_address) || options.delete(:reg_base_address) ||
                            options.delete(:base_address) || options.delete(:base) || 0
        if options[:_instance]
          if @reg_base_address.is_a?(Array)
            @reg_base_address = @reg_base_address[options[:_instance]]
          elsif options[:base_address_step]
            @reg_base_address = @reg_base_address + (options[:_instance] * options[:base_address_step])
          end
        end
        @domain_names = [options.delete(:domain) || options.delete(:domains)].flatten.compact
        @domain_specified = !@domain_names.empty?
        @path = options.delete(:path)
        @abs_path = options.delete(:abs_path) || options.delete(:absolute_path)
      end
      if is_a?(SubBlock)
        options.each do |k, v|
          send("#{k}=", v)
        end
      end
    end

    module Domains
      def domain(name, options = {})
        domains[name] = Origen::Registers::Domain.new(name, options)
      end

      def domain_specified?
        @domain_specified
      end

      def domains
        @domains ||= {}.with_indifferent_access
        if @domain_names
          @domain_names.each do |domain|
            if domain.is_a?(Origen::Registers::Domain)
              @domains[domain.id] = domain
            elsif parent.domains[domain]
              @domains[domain] = parent.domains[domain]
            else
              fail "Uknown domain: #{domain}"
            end
          end
          @domain_names = nil
        end
        if parent && @domains.empty?
          parent.domains
        else
          @domains
        end
      end
      alias_method :register_domains, :domains
    end
    include Domains

    # Jumping through some hoops here since many Origen modules talk about an owner,
    # but would prefer to start standardizing on parent in future, so this should give
    # most Origen models a parent method
    module Parent
      def parent
        @owner
      end
      alias_method :owner, :parent

      unless method_defined? :owner=
        def owner=(obj)
          if obj.respond_to?(:controller) && obj.controller
            @owner = obj.controller
          else
            @owner = obj
          end
        end
      end
      alias_method :parent=, :owner=
    end
    include Parent

    module RegBaseAddress
      def reg_base_address(options = {})
        if options[:relative]
          reg_base_address_for_domain(options)
        else
          total_reg_base_address = reg_base_address_for_domain(options)
          if parent
            total_reg_base_address += parent.reg_base_address(options)
          end
          total_reg_base_address
        end
      end

      def reg_base_address_for_domain(options)
        if @reg_base_address
          if @reg_base_address.is_a?(Hash)
            if options[:domain]
              if options[:domain].is_a?(Hash)
                domains = options[:domain].keys
              else
                domains = [options[:domain]].flatten
              end
              bases = domains.map do |d|
                @reg_base_address.with_indifferent_access[d]
              end.compact
              if bases.empty?
                @reg_base_address[:default] || 0
              else
                if bases.size > 1
                  fail 'Multiple base addresses found, specify the domain you want, e.g. reg.address(domain: :ahb)'
                else
                  bases.first
                end
              end
            else
              @reg_base_address[:default] || 0
            end
          else
            @reg_base_address
          end
        else
          0
        end
      end

      unless method_defined? :base_address
        def base_address
          reg_base_address
        end
      end
    end
    include RegBaseAddress

    module Path
      def path=(val)
        @path = val
      end

      def path_var
        @path
      end

      def abs_path=(val)
        @abs_path = val
      end
      alias_method :full_path=, :abs_path=

      def abs_path
        @abs_path
      end
      alias_method :full_path, :abs_path

      def path(options = {})
        return abs_path if abs_path
        if is_a?(Origen::Registers::BitCollection)
          # Special case where path relative to the register has been requested
          if options[:relative_to] == parent
            if size == 1
              return "[#{position}]"
            else
              return "[#{position + size - 1}:#{position}]"
            end
          else
            p = parent.parent
          end
        else
          p = parent
        end
        if p && p != options[:relative_to]
          if p.path(options).empty?
            root = ''
          else
            root = "#{p.path(options)}."
          end
        else
          # If a path variable has been set on a top-level object, then we will
          # include that in path, otherwise by default the top-level object is not
          # included in the path
          if p || path_var
            root = ''
          else
            return ''
          end
        end
        local = (path_var || name || self.class.to_s.split('::').last).to_s
        if local == 'hidden'
          root.chop
        elsif is_a?(Origen::Registers::BitCollection) && parent.path_var == :hidden
          "#{root.chop}#{local}"
        else
          "#{root}#{local}"
        end
      end
      alias_method :hdl_path, :path
    end
    include Path

    # Returns a hash containing all immediate children of the given sub-block
    def sub_blocks(*args)
      if args.empty?
        @sub_blocks ||= {}.with_indifferent_access
      else
        sub_block(*args)
      end
    end
    alias_method :children, :sub_blocks

    # Delete all sub_blocks by emptyig the Hash
    def delete_sub_blocks
      @sub_blocks = {}
    end

    def sub_blocks_array
      sub_blocks.map { |_name, sub_block| sub_block }
    end
    alias_method :children_array, :sub_blocks_array

    # Returns an array containing all descendant child objects of the given sub-block, i.e. this returns
    # an array containing children's children as well
    #
    # Note that this returns an array instead of a hash since there could be naming collisions in the
    # hash keys
    def all_sub_blocks
      @all_sub_blocks ||= begin
        (sub_blocks_array + sub_blocks_array.map(&:all_sub_blocks)).flatten
      end
    end

    # Returns true if the given sub block owns at least one register
    def owns_registers?
      if regs
        regs.is_a?(Origen::Registers::RegCollection) && !regs.empty?
      else
        false
      end
    end

    def sub_block(name, options = {})
      if i = options.delete(:instances)
        a = []
        options[:_instance] = i
        i.times do |j|
          o = options.dup
          o[:_instance] = j
          a << sub_block("#{name}#{j}", o)
        end
        define_singleton_method "#{name}s" do
          a
        end
        a
      else
        class_name = options.delete(:class_name)
        if class_name
          begin
            klass = eval("::#{namespace}::#{class_name}")
          rescue
            begin
              klass = eval(class_name)
            rescue
              begin
                klass = eval("#{self.class}::#{class_name}")
              rescue
                puts "Could not find class: #{class_name}"
                raise 'Unknown sub block class!'
              end
            end
          end
        else
          klass = Origen::SubBlock
        end
        unless klass.respond_to?(:includes_origen_model)
          puts 'Any class which is to be instantiated as a sub_block must include Origen::Model,'
          puts "add this to #{klass}:"
          puts ''
          puts '  include Origen::Model'
          puts ''
          fail 'Sub block does not include Origen::Model!'
        end
        block = klass.new(options.merge(parent: self, name: name))
        if sub_blocks[name]
          fail "You have already defined a sub-block named #{name} within class #{self.class}"
        else
          sub_blocks[name] = block
          if respond_to?(name)
            # puts "Tried to create a sub-block named #{name} in #{self.class}, but it already has a method with this name!"
            # puts "To avoid confusion rename one of them and try again!"
            # raise "Non-unique sub-block name!"
          else
            define_singleton_method name do
              sub_blocks[name]
            end
          end
        end
        block
      end
    end

    def namespace
      self.class.to_s.sub(/::[^:]*$/, '')
    end
  end

  # A simple class that will be instantiated by default when a sub block is
  # defined without another class name specified
  #
  # This class includes support for registers, pins, etc.
  class SubBlock
    include Origen::Model

    # Used to create attribute accessors on the fly.
    #
    # On first call of a missing method a method is generated to avoid the missing lookup
    # next time, this should be faster for repeated lookups of the same method, e.g. reg
    def method_missing(method, *args, &block)
      return regs(method) if self.has_reg?(method)
      return ports(method) if self.has_port?(method)
      if method.to_s =~ /=$/
        define_singleton_method(method) do |val|
          instance_variable_set("@#{method.to_s.sub('=', '')}", val)
        end
      else
        define_singleton_method(method) do
          instance_variable_get("@#{method}")
        end
      end
      send(method, *args, &block)
    end
  end
end
