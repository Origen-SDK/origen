module Origen
  # This module is responsible for enhancing how Ruby requires and loads files to support loading of
  # application models and controllers without having to require them, and more generally how the
  # contents of the various app/ sub-directories are loaded.
  module Loader
    # If a part definition exists for the given model, then this will load it and apply it to
    # the model
    def self.load_part(model, options = {})
      model = model.model  # Ensure we have a handle on the model and not its controller
      if app = options[:app] || model.app
        if options[:path]
          paths = options[:path].to_s.split('/')
        else
          paths = model.class.to_s.split('::')
          paths.shift  # Throw away the app namespace
        end
        key = ''
        # Load all parameters first so that they may be referenced in the other files
        Origen::Parameters.start_transaction
        paths.each_with_index do |path, i|
          key = i == 0 ? path.underscore : "#{key}/#{path.underscore}"
          if app.parts_files[key]
            app.parts_files[key][:parameters].each { |f| model.instance_eval(File.read(f), f) }
          end
        end
        Origen::Parameters.stop_transaction

        # Now load the rest
        paths.each_with_index do |path, i|
          key = i == 0 ? path.underscore : "#{key}/#{path.underscore}"
          if app.parts_files[key]
            app.parts_files[key][:others].each { |f| model.instance_eval(File.read(f), f) }
          end
        end
      end
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

      # Allows models and controllers to be defined in app/models and app/controllers without
      # needing to require them and without needing to put everything under a namespace directory
      # like you do with app/lib.
      #
      # The first time a reference is made to a model or controller name it will trigger this hook,
      # and we then work out what the file name should be and require it.
      #
      # Since we are handling this anyway, it will also try to consider references to files in the
      # app/lib directory.
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
            altname = nil
            # First check if this refers to a model or controller defined by a part
            dirs = [app.root, 'app', 'parts']
            names.each_with_index do |name, i|
              dirs << 'derivatives' unless i == 0
              dirs << name.underscore
            end
            if File.exist?(f = File.join(*dirs, 'model.rb'))
              model = _require_file(f, name)
              # Also load the model's controller if it exists
              if File.exist?(f = File.join(*dirs, 'controller.rb'))
                controller = _require_file(f, name + 'Controller')
              end
              return model
            end
            until names.empty?
              path = File.join(*names.map(&:underscore)) + '.rb'

              if File.exist?(f = File.join(app.root, 'app', 'lib', namespace.underscore, path))
                model = _require_file(f, name, altname)
                # Try and reference the controller to load it too, though don't raise an error if it
                # doesn't exist
                @@pre_loading_controller = true
                eval "#{altname || name}Controller"
                return model
              end

              # Don't waste time looking up the namespace hierarchy for the controller, if it exists it
              # should be within the exact same namespace as the model
              return nil if @@pre_loading_controller

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
      def _require_file(file, name, altname = nil)
        require file
        return if @@pre_loading_controller
        @_checking_name = altname || name
        const = eval(altname || name)
        @_checking_name = nil
        return const if const
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
      # Object.class_eval { include Loadable }
      Module.class_eval { include ModuleConstMissing }
    end

    def self.disable_origen_load_extensions!
      ModuleConstMissing.exclude_from(Module)
      # Loadable.exclude_from(Object)
    end
  end
end

Origen::Loader.enable_origen_load_extensions!
