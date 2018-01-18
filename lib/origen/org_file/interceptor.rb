require 'set'
module Origen
  class OrgFile
    # @api private
    #
    # Helper for the Interceptor where block_given? doesn't work internally
    def self._block_given_?(&block)
      block_given?
    end

    class Interceptor < ::BasicObject
      def initialize(object, options = {})
        @object = object
        @@locked = false unless defined? @@locked
      end

      def inspect(*args)
        @object.inspect(*args)
      end

      def ==(obj)
        if obj.respond_to?(:__org_file_interceptor__)
          @object == obj.__object__
        else
          @object == obj
        end
      end
      alias_method :equal?, :==

      def record_to_org_file(id = nil, options = {})
        id, options = nil, id if id.is_a?(::Hash)
        if options[:only]
          @org_file_methods_to_intercept = Array(options[:only]).to_set
        else
          @org_file_methods_to_intercept = default_org_file_captures
          if options[:also]
            @org_file_methods_to_intercept += Array(options[:also]).to_set
          end
        end
        @org_file ||= @old_org_file || OrgFile.org_file(id)
      end

      # Temporarily stop recording operations within the given block, or stop recording
      # completely if no block given
      def stop_recording_to_org_file(&block)
        @old_org_file = @org_file
        if OrgFile._block_given_?(&block)
          @org_file = nil
          yield
          @org_file = @old_org_file
        else
          @org_file = nil
        end
      end

      def method_missing(method, *args, &block)
        if !@@locked && @org_file && @org_file_methods_to_intercept.include?(method)
          @org_file.record(@object.global_path_to, method, *args)
          # Locking prevents an operation on an intercepted container object trigger from generating multiple
          # org file entries if its contained objects are also intercepted. e.g. Imagine this is a pin group, we
          # want the org file to reflect the operation called on the pin group, but not the many subsequent internal
          # operations as the group proxies the operation to its contained pins
          @@locked = true
          @object.send(method, *args, &block)
          @@locked = false
        else
          @object.send(method, *args, &block)
        end
      end

      def respond_to?(method, include_private = false)
        method == :__org_file_interceptor__ ||
          @object.respond_to?(method, include_private)
      end

      def __org_file_interceptor__
        true
      end

      # @api private
      #
      # Don't ever use this! An un-wrapped reference to an object must never make it into
      # application code or else any operations called on the un-wrapped reference will not
      # be captured.
      def __object__
        @object
      end

      private

      def debugger
        ::Kernel.debugger
      end

      def default_org_file_captures
        @default_captures ||= Array(@object.try(:org_file_intercepted_methods)).to_set
      end
    end
  end
end
