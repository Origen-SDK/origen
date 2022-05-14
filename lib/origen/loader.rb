module Origen
  # This module is responsible for enhancing how Ruby requires and loads files to support loading of
  # classes and modules from an application's app dir without having to require them.
  #
  # It also implements the <model>.load_block method that loads files from app/blocks.
  module Loader
    # @api private
    #
    # Unload all constants (classes and modules) that have been auto-loaded since this was last called
    def self.unload
      # puts "******** LOADED CONSTS@ #{@loaded_consts}"
      path = []
      (@consts_hierarchy || {}).each do |name, children|
        _unload(path, name, children)
      end
      @consts_hierarchy = {}
      @loaded_consts = {}
      (Origen.app.plugins + [Origen.app]).each do |app|
        app.instance_variable_set(:@blocks_files, nil)
      end
      nil
    end

    # @api private
    def self._unload(path, name, children)
      path << name
      children.each do |name, children|
        _unload(path, name, children)
      end
      const = path.join('::')
      if @loaded_consts[const]
        path[0...-1].join('::').constantize.send :remove_const, path.last
        # puts "******** Unloading: #{const}"
      end
      path.pop
    end

    # @api private
    def self.record_const(name)
      @consts_hierarchy ||= {}
      @loaded_consts ||= {}
      @loaded_consts[name] = true
      pointer = nil
      name.split('::').each do |name|
        if pointer
          pointer[name] ||= {}
          pointer = pointer[name]
        else
          @consts_hierarchy[name] ||= {}
          pointer = @consts_hierarchy[name]
        end
      end
    end

    # @api private
    def self.load_attributes(file, model)
      if model.respond_to?(:is_an_origen_model?)
        attributes = model.attributes.dup
      else
        attributes = {}
      end
      vars = model.instance_variables
      if load_block_file(file, model)
        # Update the value of any pre-existing attribute that could have just changed
        attributes.each do |a, v|
          attributes[a] = model.instance_variable_get("@#{a}")
        end
        # And add any new ones that were encountered for the first time
        (model.instance_variables - vars).each do |var|
          val = model.instance_variable_get(var)
          attribute = var.to_s.sub('@', '')
          attributes[attribute.to_sym] = val
          unless model.respond_to?(attribute)
            model.define_singleton_method(attribute) do
              instance_variable_get(var)
            end
          end
          if val == true || val == false
            attribute += '?'
            unless model.respond_to?(attribute)
              model.define_singleton_method(attribute) do
                instance_variable_get(var)
              end
            end
          end
        end
        if model.respond_to?(:is_an_origen_model?)
          attributes.freeze
          model.instance_variable_set(:@attributes, attributes)
        end
        true
      end
    end

    # @api private
    def self.load_block_file(file, model)
      file = file.to_s
      if File.exist?(file)
        File.open(file, 'r') do |f|
          model.instance_eval(f.read, file)
        end
      end
      true
    end

    # @api private
    def self.with_parameters_transaction(type)
      if type == :parameters
        Origen::Parameters.transaction do
          yield
        end
      else
        yield
      end
    end

    # If a block definition exists for the given model, then this will load it and apply it to
    # the model.
    # if options[:inherit] is passed, it will first try to load the files for the class name contained
    # in that option, even if its from a plugin app. Additionally, any bugs/features will be inherited
    # as well unless disable_bug_inheritance or disable_feature_inheritance options are passed
    # Returns true if a model is found and loaded, otherwise nil.
    def self.load_block(model, options = {})
      model = model.model # Ensure we have a handle on the model and not its controller
      loaded = nil

      if options[:inherit]
        # pass down any bugs/features from the inherited block class
        unless options[:disable_bug_inheritance]
          model.class.instance_variable_set(:@bugs, options[:inherit].constantize.bugs.merge(model.class.bugs))
        end
        unless options[:disable_feature_inheritance]
          model.class.instance_variable_set(:@features, options[:inherit].constantize.features.merge(model.class.features))
        end
      end

      if local_app = options[:app] || model.app
        if options[:path]
          local_full_paths = Array(options[:path])
        else
          local_full_paths = model.class.to_s.split('::')
          local_full_paths.shift # Throw away the app namespace
          local_full_paths = [local_full_paths.join('/')]
        end
        app_paths_map = { local_app => local_full_paths }
        if options[:inherit]
          # update app_paths_map with the relevant inherited files
          inherit_full_paths = options[:inherit].split('::')
          inherit_app = Origen.app(inherit_full_paths.shift.underscore.to_sym)
          inherit_full_paths = [inherit_full_paths.join('/')]
          # merge to get inherit ordered in the beginning
          app_paths_map = { inherit_app => inherit_full_paths }.merge(app_paths_map)
        end
        # load the inherit files, then the current app's block files
        app_paths_map.each do |app, full_paths|
          full_paths.each do |full_path|
            paths = full_path.to_s.split('/')
            key = ''
            only = Array(options[:only]) if options[:only]
            except = Array(options[:except]) if options[:except]
            path = paths.map(&:underscore).join('/')
            # If the path refers to a nested sub-block then don't load the full hierarchy since they
            # don't support inheritance or derivatives, modify the paths array so that only the sub-block
            # level will be loaded and nothing else.
            paths = [path] if app.blocks_files[path] && app.blocks_files[path][:_sub_block]
            # These will be loaded first, followed by the rest in an undefined order.
            # Attributes and parameters are first so that they may be referenced in the other files.
            # Sub-blocks was added early due to a corner case issue that could be encountered if the pins or
            # regs imported an Origen exported file that defined a module with the same name as a sub-block
            # class, in that case the sub-block class would not be auto-loaded.
            load_first = [:attributes, :parameters, :sub_blocks]

            load_first.each do |type|
              unless (only && !only.include?(type)) || (except && except.include?(type))
                with_parameters_transaction(type) do
                  paths.each_with_index do |path, i|
                    key = i == 0 ? path.underscore : "#{key}/#{path.underscore}"
                    if app.blocks_files[key] && app.blocks_files[key][type]
                      app.blocks_files[key][type].each do |f|
                        if type == :attributes
                          success = load_attributes(f, model)
                        else
                          success = load_block_file(f, model)
                        end
                        loaded ||= success
                      end
                    end
                  end
                end
              end
            end

            # Now load the rest
            paths.each_with_index do |path, i|
              key = i == 0 ? path.underscore : "#{key}/#{path.underscore}"
              if app.blocks_files[key]
                app.blocks_files[key].each do |type, files|
                  unless type == :_sub_block || load_first.include?(type) || (only && !only.include?(type)) || (except && except.include?(type))
                    files.each { |f| success = load_block_file(f, model); loaded ||= success }
                  end
                end
              end
            end
          end
        end
      end
      loaded
    end

    # This is inspired by Rails' ActiveSupport::Dependencies module.
    module ModuleConstMissing
      def self.append_features(base)
        base.class_eval do
          # Emulate #exclude via an ivar
          return if defined?(@_const_missing) && @_const_missing
          @_const_missing = instance_method(:const_missing)
          remove_method(:const_missing)
        end
        super
      end

      def self.exclude_from(base)
        base.class_eval do
          define_method :const_missing, @_const_missing
          @_const_missing = nil
        end
      end

      # @api private
      # Substitutes a single occurrence of 'derivatives' in the given dirs array, starting
      # from the end of it and replacing it with the given new value.
      # Returns true if a substitution is made, else false.
      def _sub_derivatives_from_end(new_val, dirs)
        subbed = false
        size = dirs.size - 1
        dirs.reverse_each.with_index do |val, i|
          if val == 'derivatives'
            dirs[size - i] = new_val
            subbed = true
            break
          end
        end
        dirs if subbed
      end

      # Allows classes and modules to be defined in app/blocks and app/lib without needing to
      # require them and in the case of app/blocks to use a custom directory structure.
      #
      # The first time a reference is made to a class or module name it will trigger this hook,
      # and we then work out what the file name should be and require it.
      def const_missing(name)
        if Origen.in_app_workspace?
          if self == Object
            name = name.to_s
          else
            name = "#{self}::#{name}"
          end
          return nil if @_checking_name == name
          names = name.split('::')
          namespace = names.shift
          if app = Origen::Application.from_namespace(namespace)
            # First we are going to check for a match in the app/blocks directory, this needs to be handled
            # specially since it follows a non-std structure, e.g. use of derivatives/ and sub_blocks/ folders
            # for organization without having them as part of the class name-spacing
            altname = nil
            dirs = [app.root, 'app', 'blocks']
            names.each_with_index do |name, i|
              dirs << 'derivatives' unless i == 0
              dirs << name.underscore
            end

            # Is this a reference to a model?
            if File.exist?(f = File.join(*dirs, 'model.rb'))
              model = _load_const(f, name)
              # Also load the model's controller if it exists
              if File.exist?(f = File.join(*dirs, 'controller.rb'))
                controller = _load_const(f, name + 'Controller')
              end
              return model
            end

            # Is this a reference to a controller?
            if dirs.last.to_s =~ /_controller$/
              controller_reference = true
              dirs << dirs.pop.sub(/_controller$/, '')
              if File.exist?(f = File.join(*dirs, 'controller.rb'))
                return _load_const(f, name)
              end
            end

            # Is this a reference to a sub-block model or controller that is nested within a block?
            dirs_ = dirs.dup
            while dirs_ = _sub_derivatives_from_end('sub_blocks', dirs_)
              if controller_reference
                if File.exist?(f = File.join(*dirs_, 'controller.rb'))
                  return _load_const(f, name)
                end
              elsif File.exist?(f = File.join(*dirs_, 'model.rb'))
                model = _load_const(f, name)
                # Also load the model's controller if it exists
                if File.exist?(f = File.join(*dirs_, 'controller.rb'))
                  controller = _load_const(f, name + 'Controller')
                end
                return model
              end
            end

            # Is this a reference to a module that has been added to a model or controller?
            # In this case dirs contains something like:
            #    [..., "my_model", "derivatives", "my_module"]
            #    [..., "my_model_controller", "derivatives", "my_module"]
            # So let's try by transforming these into:
            #    [..., "my_model", "model"] + "my_module.rb"
            #    [..., "my_model", "controller"] + "my_module.rb"
            filename = dirs.pop + '.rb'
            dirs.pop # Lose 'derivatives'
            if dirs.last.to_s =~ /_controller$/
              dirs << dirs.pop.sub(/_controller$/, '')
              dirs << 'controller'
            else
              dirs << 'model'
            end
            if File.exist?(f = File.join(*dirs, filename))
              return _load_const(f, name)
            end

            # Now that we have established that it is not a reference to a block (which has a non-std code
            # organization structure), we can now check for a match in the app/lib directory following std
            # Ruby code organization conventions
            until names.empty?
              path = File.join(*names.map(&:underscore)) + '.rb'

              f = File.join(app.root, 'app', 'lib', namespace.underscore, path)
              if File.exist?(f)
                model = _load_const(f, name, altname)
                # Try and reference the controller to load it too, though don't raise an error if it
                # doesn't exist
                @@pre_loading_controller = true
                eval "#{altname || name}Controller"
                return model
              # If a folder exists that is named after this constant, then assume it is an otherwise
              # undeclared namespace module and declare it now
              elsif File.exist?(f.sub('.rb', ''))
                return const_set path.sub('.rb', '').camelcase, Module.new
              end

              # Don't waste time looking up the namespace hierarchy for the controller, if it exists it
              # should be within the exact same namespace as the model
              return nil if defined?(@@pre_loading_controller) && @@pre_loading_controller

              # Remove the highest level namespace and then search again in the parent namespace
              if discarded_namespace = names.delete_at(-2)
                altname ||= name
                altname = altname.sub("#{discarded_namespace}::", '')
              else
                names.pop
              end
            end

            _raise_uninitialized_constant_error(name)
          else
            _raise_uninitialized_constant_error(name)
          end
        else
          _raise_uninitialized_constant_error(name)
        end
      ensure
        @@pre_loading_controller = false
      end

      # @api_private
      def _load_const(file, name, altname = nil)
        load file
        if defined?(@@pre_loading_controller)
          return if @@pre_loading_controller
        end
        @_checking_name = altname || name
        const = eval(altname || name)
        @_checking_name = nil
        if const
          Origen::Loader.record_const(altname || name)
          return const
        end
        msg ||= "uninitialized constant #{name} (expected it to be defined in: #{file})"
        _raise_uninitialized_constant_error(name, msg)
      end

      # @api private
      def _raise_uninitialized_constant_error(name, msg = nil)
        msg ||= "uninitialized constant #{name}"
        name_error = NameError.new(msg, name)
        name_error.set_backtrace(caller.reject { |l| l =~ /^#{__FILE__}/ })
        fail name_error
      end
    end

    def self.enable_origen_load_extensions!
      Module.class_eval { include ModuleConstMissing }
    end

    def self.disable_origen_load_extensions!
      ModuleConstMissing.exclude_from(Module)
    end
  end
end

Origen::Loader.enable_origen_load_extensions!
