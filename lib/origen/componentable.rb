module Origen

  # Protologism taking after Enumerable, stating that this object can
  # behave like an Origen Component
  module Componentable
    # Custom Componentable Errors
    
    # Raised whenever a component name tries to be added but it already exists
    class NameInUseError < StandardError
    end

    # Raised whenever a component name is used for something but does not exist.
    class NameDoesNotExistError < StandardError
    end
    
    # Raised for everything else.
    class Error < StandardError
    end

    # In order for Origen to bootstrap using a generic callback, we'll work a bit backwards.
    # When this module is included by an 'includer', it will give
    def self.included(othermod)
      self.add_included_callback(othermod)
    end
    
    # These are split in case the included module actually has an :included method defined and the user wants
    # to bootstrap setting up the add_included_callback manually.
    # Note that someone making a module to house a Componentable class is very unlikely to do this, but it could
    # still happen.
    def self.add_included_callback(othermod)
      othermod.define_singleton_method(:origen_model_init) do |klass, options={}|
        Origen::Componentable.init_parent_class(klass, self)
      end
    end

    # When Origen's model initializer is included, all Componentable objects will be automatically booted.
    def self.origen_model_init(klass, options={})
      Origen::Componentable.init_includer_class(klass)
    end
    
    # Initializes the class that included Componentable (the 'includer').
    # All of the singleton methods will be added per Ruby, but the includer still needs to be booted by:
    #  1) Creating and initializing the instance attribute (_componentable_container)
    #  2) Defining a method to get the container directly. 
    #     For example, the Component class will automatically have a :components method that references the
    #     _componentable_container.
    def self.init_includer_class(klass_instance)
      klass_instance.instance_variable_set(:@_componentable_container, {}.with_indifferent_access)
      klass_instance.class.class_eval do
        attr_reader :_componentable_container
        
        define_method Origen::Componentable.componentable_names(klass_instance)[:plural] do
          @_componentable_container
        end
      end
    end
    
    def self.parent_class_evaled?(parent_class, includer_singleton_name)
      evaled = parent_class.instance_variable_get("@_#{includer_singleton_name}_evaled")
      if evaled.nil?
        # Check that this class isn't inheriting from another class that uses Componentable things.
        # If so, the API is inherited and is fine, so set the evaled value for that class to true.
        parent_class.ancestors.each do |ancestor|
          if ancestor.instance_variable_get("@_#{includer_singleton_name}_evaled")
            parent_class.instance_variable_set("@_#{includer_singleton_name}_evaled", true)
            evaled = true
            break
          end
        end
      end
      evaled
    end
    
    def self.init_parent_class(parent_class, includer_class)
      #includer_single_name = begin
      #  if includer_class.name.include?('::')
      #    name = includer_class.name.split('::').last.underscore
      #  else
      #    name = includer_class.name.underscore
      #  end
      #end
      #includer_plural_name = Origen::Componentable.componentable_names(includer_class)[:plural]   
      
      names = Componentable.componentable_names(includer_class)
      includer_single_name = names[:singleton] 
      includer_plural_name = names[:plural] 
      
      unless parent_class.is_a?(Class)
        inc = parent_class.instance_variable_set("@_#{includer_single_name}".to_sym, includer_class.new)
        inc.parent = parent_class
        parent_class = parent_class.class
      end
      
      # If the includer's singleton name is taken (i.e., the parent already has a method <includer_single_name>),
      # raise an error since the 'proper' way to interact with the includer directly is from this method.
      if !Origen::Componentable.parent_class_evaled?(parent_class, includer_single_name) && parent_class.method_defined?(includer_single_name.to_sym)
        raise Origen::Componentable::Error, "Class #{parent_class.name} provides a method :#{includer_single_name} already. Cannot include Componentable class #{includer_class.name} in this object!"
      end
      
      # for everything that's not the singleton name method or the @_<singleton_name> instance variable, having the method
      # already exists is a warning, not an error.
      methods_to_add = [
        includer_plural_name.to_sym,
        
        # Add methods
        "add_#{includer_single_name}".to_sym,
        "add_#{includer_plural_name}".to_sym,
        
        # Listing/Querying methods
        "list_#{includer_plural_name}".to_sym,
        "#{includer_plural_name}_of_class".to_sym,
        "#{includer_plural_name}_instances_of".to_sym,
        "#{includer_plural_name}_of_type".to_sym,
        "#{includer_single_name}?".to_sym,
        "has_#{includer_single_name}?".to_sym,


        # Enumeration methods
        "each_#{includer_single_name}".to_sym,
        "all_#{includer_plural_name}".to_sym,
        "select_#{includer_plural_name}".to_sym,
        "select_#{includer_single_name}".to_sym,
        
        # Copying/Moving methods
        "copy_#{includer_single_name}".to_sym,
        "copy_#{includer_plural_name}".to_sym,
        "move_#{includer_single_name}".to_sym,
        "move_#{includer_plural_name}".to_sym,

        # Deleting individual item methods
        "delete_#{includer_single_name}".to_sym,
        "delete_#{includer_plural_name}".to_sym,
        "remove_#{includer_single_name}".to_sym,
        "remove_#{includer_plural_name}".to_sym,
        "delete_#{includer_single_name}!".to_sym,
        "delete_#{includer_plural_name}!".to_sym,
        "remove_#{includer_single_name}!".to_sym,
        "remove_#{includer_plural_name}!".to_sym,
        
        # Deleting all items methods
        "delete_all_#{includer_plural_name}".to_sym,
        "clear_#{includer_plural_name}".to_sym,
        "remove_all_#{includer_plural_name}".to_sym,
      ]
      unless Origen::Componentable.parent_class_evaled?(parent_class, includer_single_name)
        methods_to_add.each do |m|
          if parent_class.method_defined?(m)
            Origen.log.warning "Componentable: Parent class #{parent_class.name} already defines a method #{m}. This method will not be used by Componentable"
          end
        end
        parent_class.instance_variable_set("@_#{includer_single_name}_evaled".to_sym, true)
      end
      
      parent_class.class_eval do
        # Note that all of these just trace back to the root method.
        
        # Define the root method (singleton-named method)
        # If any arguments are given, it behaves as an :add method.
        # Otherwise, it returns the underlying object itself.
        define_method includer_single_name.to_sym do |*args, &block|
          if args.size == 0
            # No arguments, so just return the class instance
            instance_variable_get("@_#{includer_single_name}".to_sym)
          else
            # Arguments were provided, so treating this as an :add attempt
            instance_variable_get("@_#{includer_single_name}".to_sym).add(*args, &block)
          end
        end
        
        # Define the plural-named method.
        # If arguments are given, then it behaves as an :add attempt, with or without a block.
        # If a block is given without any arguments, it will behave as an :each operation and call the block.
        # if no arguments are given, it will return the underlying HASH (not the object).
        #   This allows for plural_name[name] to 
        define_method "#{includer_plural_name}".to_sym do |*args, &block|
          if block && args.size == 0
            instance_variable_get("@_#{includer_single_name}".to_sym).each(&block)
          elsif args.size == 0
            instance_variable_get("@_#{includer_single_name}".to_sym)._componentable_container
          else
            instance_variable_get("@_#{includer_single_name}".to_sym).add(*args, &block)
          end
        end
        
        # define the various 'add' methods
        # what we'll actually do is just define one method then alias all the others together.
        # Currently, this includes:
        #   <includer_plural_name>, add_<includer_single_name>, add_
        define_method "add_#{includer_single_name}".to_sym do |name, options={}, &block|
          instance_variable_get("@_#{includer_single_name}".to_sym).add(name, options, &block)
        end
        alias_method "add_#{includer_plural_name}".to_sym, "add_#{includer_single_name}".to_sym
      
        # define listing and getting methods
        define_method "list_#{includer_plural_name}".to_sym do
          instance_variable_get("@_#{includer_single_name}".to_sym).list
        end
        
        # define the querying object types
        define_method "#{includer_plural_name}_of_class".to_sym do |klass, options={}|
          instance_variable_get("@_#{includer_single_name}".to_sym).instances_of(klass, options)
        end
        alias_method "#{includer_plural_name}_instances_of".to_sym, "#{includer_plural_name}_of_class".to_sym
        alias_method "#{includer_plural_name}_of_type".to_sym, "#{includer_plural_name}_of_class".to_sym
        
        # define the querying instance existance
        define_method "#{includer_single_name}?".to_sym do |name|
          instance_variable_get("@_#{includer_single_name}".to_sym).has?(name)
        end
        alias_method "has_#{includer_single_name}?".to_sym, "#{includer_single_name}?".to_sym
        
        # define some of commonly used enumerate methods
        define_method "each_#{includer_single_name}".to_sym do |&block|
          instance_variable_get("@_#{includer_single_name}".to_sym).each(&block)
        end
        alias_method "all_#{includer_plural_name}".to_sym, "each_#{includer_single_name}".to_sym
        
        define_method "select_#{includer_plural_name}".to_sym do |&block|
          instance_variable_get("@_#{includer_single_name}".to_sym).select(&block)
        end
        alias_method "select_#{includer_single_name}".to_sym, "select_#{includer_plural_name}".to_sym
        
        # define the copying/moving methods
        define_method "copy_#{includer_single_name}".to_sym do |to_copy, to_location, options={}|
          instance_variable_get("@_#{includer_single_name}".to_sym).copy(to_copy, to_location, options)
        end
        alias_method "copy_#{includer_plural_name}".to_sym, "copy_#{includer_single_name}".to_sym
        
        define_method "move_#{includer_single_name}".to_sym do |to_move, to_location|
          instance_variable_get("@_#{includer_single_name}".to_sym).move(to_move, to_location)
        end
        alias_method "move_#{includer_plural_name}".to_sym, "move_#{includer_single_name}".to_sym
        
        # define the deleting single instance methods
        define_method "delete_#{includer_single_name}".to_sym do |name|
          instance_variable_get("@_#{includer_single_name}".to_sym).delete(name)
        end
        alias_method "delete_#{includer_plural_name}".to_sym, "delete_#{includer_single_name}".to_sym
        alias_method "remove_#{includer_single_name}".to_sym, "delete_#{includer_single_name}".to_sym
        alias_method "remove_#{includer_plural_name}".to_sym, "delete_#{includer_single_name}".to_sym
        
        define_method "delete_#{includer_single_name}!".to_sym do |name|
          instance_variable_get("@_#{includer_single_name}".to_sym).delete!(name)
        end
        alias_method "delete_#{includer_plural_name}!".to_sym, "delete_#{includer_single_name}!".to_sym
        alias_method "remove_#{includer_single_name}!".to_sym, "delete_#{includer_single_name}!".to_sym
        alias_method "remove_#{includer_plural_name}!".to_sym, "delete_#{includer_single_name}!".to_sym
        
        # define the deleting all instances methods
        define_method "delete_all_#{includer_plural_name}".to_sym do
          instance_variable_get("@_#{includer_single_name}".to_sym).delete_all
        end
        alias_method "clear_#{includer_plural_name}".to_sym, "delete_all_#{includer_plural_name}".to_sym
        alias_method "remove_all_#{includer_plural_name}".to_sym, "delete_all_#{includer_plural_name}".to_sym
        
      end
    end
    
    # All of these are generic names and the instantiation. When included, Componentable will add aliases to these
    # methods onto the includer's parent. For example:
    #   <includer>.has? becomes $dut.has_<include>?
    #   <includer>.delete(name_to_delete) becomes $dut.delete_<includer>(name_to_delete)
    #   etc. etc.
    #def self.parent_or_owner(includer)
    #  return includer.parent if includer.parent
    #  return includer.owner if includer.owner
    #  nil
    #end
    
    # Gets the plural name of the class.
    def _plural_name
      @plural_name || begin
        @plural_name = Origen::Componentable.componentable_names(self)[:plural]
        @singleton_name = Origen::Componentable.componentable_names(self)[:singleton]
      end
    end
    
    # Gets the singleton name of the class.
    def _singleton_name
      @singleton_name || begin
        @plural_name = Origen::Componentable.componentable_names(self)[:plural]
        @singleton_name = Origen::Componentable.componentable_names(self)[:singleton]
      end
    end
    
    # Gets the parent of the includer class.
    def parent
      @parent
    end
    
    # Sets the parent of the includer class
    def parent=(p)
      @parent = p
    end
    
    def self.componentable_names(klass)
      unless klass.is_a?(Class)
        # If we were given an instance of a class, get its actual class.
        klass = klass.class
      end
      names = Hash.new
      
      # Evaluate the singleton name. This will be the class name or the class constant
      #  COMPONENTABLE_SINGLETON_NAME, if it's defined.
      # The only corner case here is if the class is anonymous, then a COMPONENTABLE_SINGLETON_NAME is required.
      if klass.const_defined?(:COMPONENTABLE_SINGLETON_NAME)
        names[:singleton] = klass.const_get(:COMPONENTABLE_SINGLETON_NAME).downcase.to_sym
      else
        # Check if this is an anonymous class. If so, complain that COMPONENTABLE_SINGLETON_NAME is required
        if !klass.respond_to?(:name) || klass.name.nil? #|| klass.name.start_with?('#<Class:')
          if klass.const_defined?(:COMPONENTABLE_PLURAL_NAME)
            # Have a more specific error saying the plural name was found but isn't sufficient.
            raise Origen::Componentable::Error, 'Anonymous classes that include the Componentable module must define COMPONENTABLE_SINGLETON_NAME, even if COMPONENTABLE_PLURAL_NAME is defined'            
          else
            raise Origen::Componentable::Error, 'Anonymous classes that include the Componentable module must define COMPONENTABLE_SINGLETON_NAME'
          end
        else
          if klass.name.include?('::')
            names[:singleton] = klass.name.split('::').last.underscore.to_sym
          else
            names[:singleton] = klass.name.underscore.to_sym
          end
        end
      end
      
      if klass.const_defined?(:COMPONENTABLE_PLURAL_NAME)
        name = klass.const_get(:COMPONENTABLE_PLURAL_NAME).downcase.to_sym
        
        # do a quick check to make sure that the plural name and singleton name aren't set to the same thing
        if name == names[:singleton]
          raise Origen::Componentable::Error, "Componentable including class cannot define both COMPONENTABLE_SINGLETON_NAME and COMPONENTABLE_PLURAL_NAME to '#{name}'"
        end
      else
        name = names[:singleton].to_s
        
        # Only deal with a few cases here, I'm not interested in figuring out every
        # english rule to pluralize everything. Examples:
        #   deer => deers (not deer, though technically I think deers is actually a word, but an odd one)
        #   goose => gooses (not geese)
        #   dwarf => dwarfs (not dwarves)
        # If the user is concerned about this, they can supply their own
        # name pluralizing their class name directly.
        if name.match /is$/
          #   analysis => analyses
          name.gsub!(/is$/, 'es')
        elsif name.match /[sxz]$|sh$|ch$/
          # if the names ends with s, h, ch, sh, x, z: append 'es'. Examples:
          #   bus => buses
          #   stress => stresses
          #   box => boxes
          #   branch => branches
          #   brush => brushes
          #   tax => taxes
          #   buzz => buzzes
          name += 'es'
        elsif name.match /on$/
          #   criterion => criteria
          name.gsub!(/on$/, 'a')
        else
          # just append a single 's'. Examples:
          #   component => components
          #   sub_block => sub_blocks
          #   tool => tools
          name += 's'
        end
        name = name.to_sym
      end
      names[:plural] = name
      
      names
    end
    
    def add(name, options={}, &block)
      instances = _split_by_instances(name, options, &block)
      return_instances = []
      instances.each do |n, opts|
        return_instances << _add(n, opts)
      end
      
      return_instances.size == 1 ? return_instances.first : return_instances
    end
    
    def _split_by_instances(name, options={}, &block)
      if !options[:instances].nil? && options[:instances] > 1
        instances = {}
        options[:instances].times do |i|
          opts = {}
          
          # merge the given options with any that are overriden with the block.
          if block_given?
            collector = Origen::Utility::Collector.new
            yield collector
            options.merge!(collector.store)
          end
          
          # go through the options one by one now and make sure that each element is either an array to be split
          # by the instances, or is a single object. If not one of these two, complain.
          options.each do |key, val|
            if val.is_a?(Array)
              if val.size == 1
                # An array with a single element. This is fine. Just take that single element as the contents.
                # Note: this is a workaround for the corner case of wanting to pass in an array as an option
                # with a size that doesn't match the number of instances.
                opts[key] = val.first
              elsif val.size != options[:instances]
                # The number of elements in the option doesn't match the number of instances, and it greater than
                # a single element.
                raise Origen::Componentable::Error, "Error when adding #{name}: size of given option :#{key} (#{val.size}) does not match the number of instances specified (#{options[:instances]})"
              else
                # use the index number to grab the correct value for this instance
                opts[key] = val[i]
              end
            else
              opts[key] = val
            end
          end
          
          # set the instance's name and add it and its options to the list to be added
          instances["#{name}#{i}".to_sym] = opts
        end
        instances
      else
        if block_given?
          collector = Origen::Utility::Collector.new
          yield collector
          options.merge!(collector.store)
        end
        {name => options}
      end
    end
    
    # Adds a new item to the componentable container.
    # @note All options added will be passed to the subclasses instantiation.
    # @note The options is only valid for the stock :add method.
    # @note Any extra options provided are still passed to the subclasses instantiation.
    # @param name [Symbol] Name to reference the new component object.
    # @param options [Hash] Customizations for both the add method and for the class's instantiation.
    # @option options [Class, String] class_name The class to instaniate the component at :name as.
    # @return [ComponentableObject] The instantiated class at :name
    # @raise [Origen::Componentable::NameInUseError] Raised if :name already points to a component.
    def _add(name, options={}, &block)
      # Add the name and parent to the options if they aren't already given
      # If the parent isn't available on the includer class, it will remain nil.
      options = {
        name: name,
        parent: parent
      }.merge(options)
      
      if block_given?
        collector = Origen::Utility::Collector.new
        yield collector
        options.merge!(collector.store)
      end
      
      # Instantiate the class. This will place the object in the @_componentable_container at the indicated name
      _instantiate_class(name, options)
      
      # Create an accessor for the new item, if indicated to do so.
      _push_accessor(name, options)
      
      @_componentable_container[name]
    end
    
    def _instantiate_class(name, options)
      if @_componentable_container.key?(name)
        raise Origen::Componentable::NameInUseError, "#{self._singleton_name} name :#{name} is already in use."
      end
      
      if options[:class_name]
        class_name = options.delete(:class_name)
        
        if !Object.const_defined?(class_name.to_s)
          raise Origen::Componentable::NameDoesNotExistError, "class_name option '#{class_name}' cannot be found"
        end
        
        # Instantiate the given class
        if class_name.is_a?(String)
          @_componentable_container[name] = eval(class_name).new(options)
        else class_name.is_a?(Class)
          @_componentable_container[name] = class_name.new(options)
        end
      else
        # Instantiate a standard Component if no class given
        @_componentable_container[name] = Origen::Component::Default.new(options)
      end
      @_componentable_container[name]
    end
    
    def _push_accessor(name, options)
      if parent
        def push_accessor(name)
          if parent.respond_to?(name.to_sym)
            Origen.log.warn("Componentable: #{_singleton_name} is trying to add an accessor for item :#{name} to parent #{parent.class.name} but that method already exist! No accessor will be added.")
          else
            parent.send(:eval, "define_singleton_method :#{name.to_sym} do; #{_singleton_name}[:#{name}]; end")
          end
        end
        
        if self.class.const_defined?(:COMPONENTABLE_ADDS_ACCESSORS) && self.class.const_get(:COMPONENTABLE_ADDS_ACCESSORS)
          if parent.respond_to?(:disable_componentable_accessors)
            if parent.method(:disable_componentable_accessors).arity >= 1
              if !parent.disable_componentable_accessors(self.class)
                push_accessor(name)
              end
            else
              if !parent.disable_componentable_accessors
                push_accessor(name)
              end
            end
          else
            push_accessor(name)
          end
        end
      end
    end
    
    # List the items in the componentable container
    # @return [Array<Symbol>] Componentable container item names.
    def list
      @_componentable_container.keys
    end
    
    # Checks if a component exist in the componentable container.
    # @param name [Symbol] Name to query existance of.
    # @return [true, false] True if :name exists, False otherwise.
    def has?(name)
      @_componentable_container.include?(name)
    end
    
    def [](name)
      @_componentable_container[name]
    end
    
    # Copies the component at :to_copy to :to_location. Default is to deep copy (i.e. clone)
    # the to_copy, resulting in two independent components.
    # @param to_copy [Symbol] Name of the component to copy.
    # @param to_location [Symbol] Name to copy to.
    # @param options [Hash] Customization options.
    # @option options [true, false] :deep_copy (true) Indicates whether to deep copy (clone) the component or just copy the a reference to the component.
    # @option options [true, false] :override (false) Indicates if the object at :to_location should be overridden if it already exists.
    # @returns [Symbol] The new object (or reference to) at :to_location.
    # @raise [Origen::Componentable::NameInUseError] Raised if :to_location is already in use and the :override option is not specified.
    # @raise [Origen::Componentable::NameDoesNotExistsError] Raised if :to_copy name does not exists.
    def copy(to_copy, to_location, options={})
      deep_copy = options.key?(:deep_copy) ? options[:deep_copy] : true
      overwrite = options[:overwrite] || false
      
      if @_componentable_container.key?(to_location) && !overwrite
        # The copy location already exists and override was not specified
        raise Origen::Componentable::NameInUseError, "#{self._singleton_name} name :#{to_location} is already in use"
      end
      
      unless @_componentable_container.key?(to_copy)
        # The to copy name doesn't exist
        raise Origen::Componentable::NameDoesNotExistError, "#{self._singleton_name} name :#{to_copy} does not exist"
      end
      
      if deep_copy
        @_componentable_container[to_location] = @_componentable_container[to_copy].clone
      else
        @_componentable_container[to_location] = @_componentable_container[to_copy]
      end
    end

    # Moves a component object from one name to another.
    # @param to_move [Symbol] Component name to move elsewhere.
    # @param new_name [Symbol] New name to give to the component from :to_move.
    # @return [Symbol] The component moved.
    # @raise [Origen::Componentable::NameInUseError] Raised if :new_name is already in use and the :override option is not specified.
    # @raise [Origen::Componentable::NameDoesNotExistsError] Raised if :to_move name does not exists.
    def move(to_move, new_name, options={})
      overwrite = options[:overwrite] || false
    
      if @_componentable_container.key?(new_name) && !overwrite
        # The move location already exists and override was not specified
        raise Origen::Componentable::NameInUseError, "#{self._singleton_name} name :#{new_name} is already in use"
      end
      
      unless @_componentable_container.key?(to_move)
        # The to_move name doesn't exist
        raise Origen::Componentable::NameDoesNotExistError, "#{self._singleton_name} name :#{to_move} does not exist"
      end

      to_move_object = @_componentable_container.delete(to_move)
      @_componentable_container[new_name] = to_move_object
    end

    # Deletes a component from the componentable container
    # @param name [Symbol] Name of component to delete
    # @return [Hash(Symbol, <ComponentableItem>)]  containing the name of the component deleted and its component.
    # @raise [Origen::Componentable::NameDoesNotExistsError] Raised if :to_copy name does not exists.
    def delete(to_delete)
      obj = delete!(to_delete)
      raise Origen::Componentable::NameDoesNotExistError, "#{self._singleton_name} name :#{to_delete} does not exist" if obj.nil?
      obj
    end
    alias_method :remove, :delete
    
    # Same as the :delete method but raises an error if :name doesn't exists.
    # @param name [Symbol] Name oof the component to delete.
    # @return [Hash(Symbol, <ComponentableItem>), nil] Hash containing the name of the component deleted and its component. Nil if the name doesn't exist.
    def delete!(to_delete)
      need_to_undef = parent && parent.respond_to?(to_delete) && parent.send(to_delete).eql?(@_componentable_container[to_delete])
      
      obj = @_componentable_container.delete(to_delete)
      
      if need_to_undef
        parent.instance_eval "undef #{to_delete}"
      end
      
      obj
    end
    alias_method :remove!, :delete!
    
    # Deletes all of the components in the container.
    # @return [Hash(Symbol, <ComponentableItem>)] Hash containing all of the deleted items.
    def delete_all
      # delete individual objects one by one, making sure to delete all accessors as well
      returns = {}
      @_componentable_container.each do |key, val|
        delete!(key)
        returns[key] = val
      end
      returns
    end
    alias_method :clear, :delete_all
    alias_method :remove_all, :delete_all
    
    # Locates all names whose object is a :class_name object.
    # @param class_name [Class, Instance of Class] Class to search componentable container for. This can either be the class name, or can be an instance of the class to search for.
    # @return [Array <Strings>] An array listing all of the names in the componentable container which are a :class_name.
    def instances_of(class_name, options={})
      unless class_name.is_a?(Class)
      	# class_name is actually an instance of the class to search for, not the class itself.
        class_name = class_name.class
      end
      @_componentable_container.select do |name, component|
        component.is_a?(class_name)
      end.keys
    end
    
    # Implementation for an each method
    def each(&block)
      @_componentable_container.each(&block)
    end
    
    # Implementation for a select method
    def select(&block)
      @_componentable_container.select(&block)
    end
    
  end
end
