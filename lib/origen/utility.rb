module Origen
  module Utility
    autoload :Diff,        'origen/utility/diff'
    autoload :Mailer,      'origen/utility/mailer'
    autoload :CSV,     'origen/utility/csv_data'
    autoload :TimeAndDate, 'origen/utility/time_and_date'
    autoload :InputCapture, 'origen/utility/input_capture'
    autoload :BlockArgs, 'origen/utility/block_args'
    autoload :FileDiff,  'origen/utility/file_diff.rb'
    autoload :Collector, 'origen/utility/collector.rb'

    # Creates a hex-like representation of a register read value, where bits within
    # a nibble have different flags set the nibble will be expanded to bits
    #
    #   read_hex(0x55)              # => "0x55"
    #   read_hex(nil)               # => "0xX"
    #
    #   myreg.size                  # => 32
    #
    #   read_hex(myreg)             # =>  "0xXXXXXXXX"
    #   myreg[7..4].store
    #   read_hex(myreg)             # =>  "0xXXXXXXSX"
    #   myreg[23..16].read
    #   read_hex(myreg)             # =>  "0xXX00XXSX"
    #   myreg[23..16].read(0x12)
    #   read_hex(myreg)             # =>  "0xXX12XXSX"
    #   reg[31..28].overlay("sub")
    #   reg[31..28].read
    #   read_hex(myreg)             # =>  "0xVX12XXSX"
    #   reg[5].clear_flags
    #   read_hex(myreg)             # =>  "0xVX12XX_ssxs_X"
    #   reg[21].overlay("sub")
    #   reg[18].store
    #   read_hex(myreg)             # =>  "0xVX_00v1_0s10_XX_ssxs_X"
    def self.read_hex(reg_or_val)
      if reg_or_val.respond_to?(:data)
        # Make a binary string of the data, like 010S0011SSSS0110
        # (where S, X or V represent store, dont care or overlay)
        regval = ''
        reg_or_val.shift_out_left do |bit|
          if bit.is_to_be_stored?
            regval += 'S'
          elsif bit.is_to_be_read?
            if bit.has_overlay?
              regval += 'V'
            else
              regval += bit.data.to_s
            end
          else
            regval += 'X'
          end
        end

        # Now group by nibbles to give a hex-like representation, and where nibbles
        # that are not all of the same type are expanded, e.g. -010s-3S6
        outstr = ''
        regex = '^'
        r = reg_or_val.size % 4
        unless r == 0
          regex += '(' + ('.' * r) + ')'
        end
        (reg_or_val.size / 4).times { regex += '(....)' }
        regex += '$'
        Regexp.new(regex) =~ regval

        nibbles = []
        (reg_or_val.size / 4).times do |n|                   # now grouped by nibble
          nibbles << Regexp.last_match[n + 1]
        end
        unless r == 0
          nibbles << Regexp.last_match[(reg_or_val.size / 4) + 1]
        end

        nibbles.each_with_index do |nibble, i|
          # If contains any special chars...
          if nibble =~ /[XSV]/
            # If all the same...
            if nibble.split('').all? { |c| c == nibble[0] }
              outstr += nibble[0, 1] # .to_s
            # Otherwise present this nibble in 'binary' format
            else
              outstr += (i == 0 ? '' : '_') + nibble.downcase + (i == nibbles.size - 1 ? '' : '_')
            end
          # Otherwise if all 1s and 0s...
          else
            outstr += '%1X' % nibble.to_i(2)
          end
        end
        "0x#{outstr.gsub('__', '_')}"

      else
        if reg_or_val
          reg_or_val.to_hex
        else
          '0xX'
        end
      end
    end
  end
end
