module Origen
  module NVM
    # A block array is a standard Ruby array that has been enhanced with additional
    # methods related to the fact that it is intended to hold NVM block objects.
    #
    # This for example allows a block select value to be automatically generated for
    # whatever blocks are contained in the array by calling the bsel method.
    class BlockArray < ::Array
      # Return all single blocks wrapped in a block array
      def [](ix)
        BlockArray.new << super(ix)
      end

      # Extract a subset of blocks based on ids
      #
      #   $nvm.blocks.find(0,3)
      #
      # An elegant way to implement this is via an accessor like this on your top-level
      # object which owns the blocks:
      #
      #   def blocks(*args)
      #     if args.empty?
      #       @blocks
      #     else
      #       @blocks.find(*args)
      #     end
      #   end
      #   alias :block :blocks
      #
      # This provides the following API:
      #
      #   $nvm.blocks        # Returns all blocks
      #   $nvm.block(0)      # Returns block 0 wrapped in a block array
      #   $nvm.blocks(0, 3)  # Returns blocks 0 and 3 wrapped in a block array
      def find(*ids)
        b = BlockArray.new
        ids.each do |id|
          b << self[id]
        end
        b
      end

      # def method_missing(method, *args, &blk)
      #  if self.size == 1
      #    self.first.send(method, *args, &blk)
      #  else
      #    super
      #  end
      # end

      # Returns the block select value required to select all contained blocks, the block object
      # must implement a method called bsel for this to work
      def bsel
        reduce(0) { |bsels, block| bsels | block.bsel }
      end
      alias_method :block_select, :bsel
      alias_method :block_select_value, :bsel

      # Returns the sum of the size of all contained blocks in KB, the block object must implement
      # a method called size_in_kb for this to work
      def size_in_kb
        reduce(0) { |sum, block| sum + block.size_in_kb }
      end

      # Returns the sum of the size of all contained blocks in bytes, the block object must implement
      # a method called size_in_kb for this to work
      def size_in_bytes
        size_in_kb * 1024
      end
    end
  end
end
