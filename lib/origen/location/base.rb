module Origen
  module Location
    # A Location is an abstract object used to represent any NVM location
    # of interest, such as a pass code, security field, etc.
    class Base
      attr_accessor :address, :endian, :size_in_bytes, :owner

      alias_method :byte_address, :address
      alias_method :byte_aligned_byte_address, :address
      alias_method :endianess, :endian

      def initialize(options = {})
        options = {
          size_in_bytes:      1,
          word_size_in_bytes: 2,
          endian:             :big,
          data:               0,
          nil_state:          0
        }.merge(options)
        @address = options.delete(:address) || options.delete(:byte_address)
        @endian = options.delete(:endian)
        @size_in_bytes = options.delete(:size_in_bytes)
        @nil_state = options.delete(:nil_state)
        @owner = options.delete(:owner)
        write(options.delete(:data), size_in_bytes: @size_in_bytes)
        create_address_methods(options)
      end

      def aligned_address(bytes)
        f = bytes - 1
        (address >> f) << f
      end

      def big_endian?
        endian == :big
      end

      def little_endian?
        endian == :little
      end

      def write(data, options = {})
        @current_data = data
        @current_data_size_in_bytes = options[:size_in_bytes] || size_in_bytes
        self.data(options)
      end
      alias_method :set, :write

      def data(options = {})
        data = @current_data
        nil_val = options[:nil_state] || @nil_state
        shift = 8 * (size_in_bytes - @current_data_size_in_bytes)
        mask = (1 << shift) - 1
        if big_endian?
          data <<= shift
          if nil_val == 1 && shift != 0
            data |= mask
          end
        else
          if nil_val == 1
            data |= (mask << shift)
          end
        end
        data
      end
      alias_method :value, :data
      alias_method :val, :data

      def read!(*args)
        action!(:read, *args)
      end

      def write!
        action!(:write, *args)
      end

      def store!
        action!(:store, *args)
      end

      def program!
        action!(:program, *args)
      end

      def erase!
        action!(:erase, *args)
      end

      private

      def action!(type, *args)
        if owner
          owner.send(type, self, *args)
        else
          fail "To #{type} a location an owner must be assigned to it!"
        end
      end

      def create_address_methods(options)
        options.each do |key, value|
          if key.to_s =~ /(\w+)_size_in_bytes$/
            define_singleton_method("#{Regexp.last_match[1].downcase}_aligned_address") do
              aligned_address(value)
            end
            define_singleton_method("#{Regexp.last_match[1].downcase}_aligned_byte_address") do
              aligned_address(value)
            end
            define_singleton_method("#{Regexp.last_match[1].downcase}_address") do
              address / value
            end
          end
        end
      end
    end
  end
end
