# This file was generated by Origen, any hand edits will likely get overwritten
# rubocop:disable all
module Origen
  module Export1
    module Block1
      def self.extended(model)
        model.sub_block :x, file: 'origen/export1/block1/x.rb', dir: '/scratch/nxa21353/Code/github/origen/vendor/lib/models', lazy: true, base_address: 0x40000000

      end
    end
  end
end
# rubocop:enable all
