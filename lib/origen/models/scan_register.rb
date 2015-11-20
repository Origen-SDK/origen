module Origen
  module Models
    class ScanRegister
      include Origen::Model

      attr_reader :size

      def initialize(options = {})
        # The shift register
        reg :sr, 0, size: size, reset: options[:reset] || 0
        # The update register, this is the value presented to the outside world
        reg :ur, 0, size: size, reset: options[:reset] || 0

        port :si              # Scan in
        port :so              # Scan out
        port :c, size: size   # Capture in

        # Control signals
        port :se  # Shift enable
        port :ce  # Capture enable
        port :ue  # Update enable

        so.connect_to(sr[0])
      end

      def method_missing(method, *args, &block)
        if BitCollection.instance_methods.include?(method)
          ur.send(method, *args, &block)
        else
          super
        end
      end

      def respond_to?(*args)
        super(*args) || BitCollection.instance_methods.include?(args.first)
      end

      def mode
        if se.data == 1
          :shift
        elsif ce.data == 1
          :capture
        elsif ue.data == 1
          :update
        else
          undefined
        end
      end

      def clock_prepare
        @mode = mode
        if @mode == :shift
          @din = si.data
        elsif @mode == :capture
          @din = c.data
        elsif @mode == :update
          @din = sr.data
        end
      end

      def clock_apply
        if @mode == :shift
          sr.shift_right(@din)
        elsif @mode == :capture
          sr.write(@din)
        elsif @mode == :update
          ur.write(@din)
        end
        @din = nil
        @mode = nil
      end

      def default_connection
        ur
      end
    end
  end
end
