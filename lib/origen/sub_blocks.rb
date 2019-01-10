module Origen
  module SubBlocks
    # This will be called whenever an object that includes this module
    # is instantiated
    #
    # @api private
    def init_sub_blocks(*args)
      options = args.find { |a| a.is_a?(Hash) }
      @custom_attrs = (options ? options.dup : {}).with_indifferent_access
      # Delete these keys which are either meta data added by Origen or are already covered by
      # dedicated methods
      %w(parent name base_address reg_base_address base).each do |key|
        @custom_attrs.delete(key)
      end
      if options
        # Using reg_base_address for storage to avoid class with the original Origen base
        # address API, but will accept any of these
        @reg_base_address = options.delete(:reg_base_address) ||
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

    # Returns the default
    def self.lazy?
      @lazy || false
    end

    def self.lazy=(value)
      @lazy = value
    end

    # Returns a hash containing all options that were passed to the sub_block definition
    def custom_attrs
      @custom_attrs
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

    # Delete all sub_blocks by emptying the Hash
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
    alias_method :has_regs?, :owns_registers?

    def has_fuses?
      fuses.empty? ? false : true
    end

    def has_tests?
      tests.empty? ? false : true
    end

    def sub_block(name, options = {})
      if i = options.delete(:instances)
        # permit creating multiple instances of a particular sub_block class
        # can pass array for base_address, which will be processed above
        a = []
        unless respond_to?("#{name}s")
          define_singleton_method "#{name}s" do
            a
          end
        end
        options[:_instance] = i
        i.times do |j|
          o = options.dup
          o[:_instance] = j
          a << sub_block("#{name}#{j}", o)
        end
        a
      else
        block = Placeholder.new(self, name, options)
        # Allow additional attributes to be added to an existing sub-block if it hasn't
        # been instantiated yet. This is not supported yet for instantiated sub-blocks since
        # there are probably a lot more corner-cases to consider, and hopefully no one will
        # really need this anyway.
        if sub_blocks[name] && !sub_blocks[name].is_a?(Placeholder)
          fail "You have already defined a sub-block named #{name} within class #{self.class}"
        end
        unless respond_to?(name)
          define_singleton_method name do
            get_sub_block(name)
          end
        end
        if sub_blocks[name] && sub_blocks[name].is_a?(Placeholder)
          sub_blocks[name].add_attributes(options)
        else
          sub_blocks[name] = block
        end
        unless @current_group.nil?  # a group is currently open, store sub_block id only
          @current_group << name
        end
        if options.key?(:lazy)
          lazy = options[:lazy]
        else
          lazy = Origen::SubBlocks.lazy?
        end
        lazy ? block : block.materialize
      end
    end

    # Create a group of associated sub_blocks under a group name
    # permits each sub_block to be of a different class
    # e.g.
    # sub_block_group :my_ip_group do
    #   sub_block :ip0, class_name: 'IP0', base_address: 0x000000
    #   sub_block :ip1, class_name: 'IP1', base_address: 0x000200
    #   sub_block :ip2, class_name: 'IP2', base_address: 0x000400
    #   sub_block :ip3, class_name: 'IP3', base_address: 0x000600
    # end
    #
    # creates an array referenced by method called 'my_ip_group'
    # which contains the sub_blocks 'ip0', 'ip1', 'ip2', 'ip3'.
    #
    # Can also indicate a custom class container to hold these.
    # This custom class container MUST support a '<<' method in
    # order to add new sub_blocks to the container instance.
    #
    # e.g.
    # sub_block_group :my_ip_group, class_name: 'MYGRP' do
    #   sub_block :ip0, class_name: 'IP0', base_address: 0x000000
    #   sub_block :ip1, class_name: 'IP1', base_address: 0x000200
    #   sub_block :ip2, class_name: 'IP2', base_address: 0x000400
    #   sub_block :ip3, class_name: 'IP3', base_address: 0x000600
    # end
    #
    #
    def sub_block_group(id, options = {})
      @current_group = []    # open group
      yield                  # any sub_block calls within this block will have their ID added to @current_group
      my_group = @current_group.dup
      define_singleton_method "#{id}" do
        if options[:class_name]
          b = Object.const_get(options[:class_name]).new
        else
          b = []
        end
        my_group.each do |group_id|
          b << send(group_id)
        end
        b                         # return array inside new singleton method
      end
      @current_group = nil   # close group
    end
    alias_method :sub_block_groups, :sub_block_group
    alias_method :sub_blocks_groups, :sub_block_group
    alias_method :sub_blocks_group, :sub_block_group

    def namespace
      self.class.to_s.sub(/::[^:]*$/, '')
    end

    private

    def get_sub_block(name)
      sub_blocks[name]
    end

    def instantiate_sub_block(name, klass, options)
      return sub_blocks[name] unless sub_blocks[name].is_a?(Placeholder)
      sub_blocks[name] = klass.new(options.merge(parent: self, name: name))
    end

    class Placeholder
      attr_reader :name, :owner, :attributes

      def initialize(owner, name, attributes)
        @owner = owner
        @name = name
        @attributes = attributes
      end

      def add_attributes(attrs)
        @attributes = @attributes.merge(attrs)
      end

      # Make this appear like a sub-block to any application code
      def class
        klass
      end

      # Make this appear like a sub-block to any application code
      def is_a?(klass)
        # Because sub_blocks are stored in a hash.with_indifferent_access, the value is tested
        # against being a Hash or Array when it is added to the hash. This prevents the class being
        # looking up and loaded by the autoload system straight away, especially if the sub-block
        # has been specified to lazy load
        return false if klass == Hash || klass == Array
        klass == self.klass || klass == Placeholder
      end

      # Make it look like a sub-block in the console to avoid confusion
      def inspect
        "<SubBlock: #{name}>"
      end

      def method_missing(method, *args, &block)
        materialize.send(method, *args, &block)
      end

      def respond_to?(method, include_private = false)
        materialize.respond_to?(method, include_private)
      end

      def materialize
        block = nil
        file = attributes.delete(:file)
        load_part = attributes.delete(:load_part)
        dir = attributes.delete(:dir) || owner.send(:export_dir)
        block = owner.send(:instantiate_sub_block, name, klass, attributes)
        if file
          require File.join(dir, file)
          block.extend owner.send(:export_module_names_from_path, file).join('::').constantize
        end
        block.load_part(load_part) if load_part
        block.owner = owner
        block
      end

      def ==(obj)
        if obj.is_a?(Placeholder)
          materialize == obj.materialize
        else
          materialize == obj
        end
      end
      alias_method :equal?, :==

      def freeze
        materialize.freeze
      end

      def clone
        materialize.clone
      end

      def dup
        materialize.dup
      end

      def to_json(*args)
        materialize.to_json(*args)
      end

      def klass
        @klass ||= begin
          class_name = attributes.delete(:class_name)
          if class_name
            begin
              klass = eval("::#{owner.namespace}::#{class_name}")
            rescue NameError
              begin
                klass = eval(class_name)
              rescue NameError
                begin
                  klass = eval("#{owner.class}::#{class_name}")
                rescue NameError
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
          klass
        end
      end
    end
  end

  # A simple class that will be instantiated by default when a sub block is
  # defined without another class name specified
  #
  # This class includes support for registers, pins, etc.
  class SubBlock
    include Origen::Model

    # Since no application defined this sub-block class, consider its parent's app to be
    # the owning application
    def app
      parent.app
    end

    # Used to create attribute accessors on the fly.
    #
    # On first call of a missing method a method is generated to avoid the missing lookup
    # next time, this should be faster for repeated lookups of the same method, e.g. reg
    def method_missing(method, *args, &block)
      super
    rescue NoMethodError
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
