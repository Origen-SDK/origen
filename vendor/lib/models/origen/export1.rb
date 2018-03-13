# This file was generated by Origen, any hand edits will likely get overwritten
# rubocop:disable all
module Origen
  module Export1
    def self.extended(model)
      model.add_package :bga
      model.add_package :pcs
      model.add_pin :pinx
      model.add_pin :piny, reset: :drive_hi, direction: :output, meta: { a: '1', b: 2 }
      model.add_pin :tdo, packages: { bga: { location: 'BF32', dib_assignment: [10104] }, pcs: { location: 'BF30', dib_assignment: [31808] } }
      model.add_pin :porta31
      model.add_pin :porta30
      model.add_pin :porta29
      model.add_pin :porta28
      model.add_pin :porta27
      model.add_pin :porta26
      model.add_pin :porta25
      model.add_pin :porta24
      model.add_pin :porta23
      model.add_pin :porta22
      model.add_pin :porta21
      model.add_pin :porta20
      model.add_pin :porta19
      model.add_pin :porta18
      model.add_pin :porta17
      model.add_pin :porta16
      model.add_pin :porta15
      model.add_pin :porta14
      model.add_pin :porta13
      model.add_pin :porta12
      model.add_pin :porta11
      model.add_pin :porta10
      model.add_pin :porta9
      model.add_pin :porta8
      model.add_pin :porta7
      model.add_pin :porta6
      model.add_pin :porta5
      model.add_pin :porta4
      model.add_pin :porta3
      model.add_pin :porta2
      model.add_pin :porta1
      model.add_pin :porta0
      model.add_pin :portb0
      model.add_pin :portb1
      model.add_pin :portb2
      model.add_pin :portb3
      model.add_pin :portb4
      model.add_pin :portb5
      model.add_pin :portb6
      model.add_pin :portb7
      model.add_pin :portb8
      model.add_pin :portb9
      model.add_pin :portb10
      model.add_pin :portb11
      model.add_pin :portb12
      model.add_pin :portb13
      model.add_pin :portb14
      model.add_pin :portb15
      model.add_pin_group :porta, :porta31, :porta30, :porta29, :porta28, :porta27, :porta26, :porta25, :porta24, :porta23, :porta22, :porta21, :porta20, :porta19, :porta18, :porta17, :porta16, :porta15, :porta14, :porta13, :porta12, :porta11, :porta10, :porta9, :porta8, :porta7, :porta6, :porta5, :porta4, :porta3, :porta2, :porta1, :porta0
      model.add_pin_group :portb, :portb15, :portb14, :portb13, :portb12, :portb11, :portb10, :portb9, :portb8, :portb7, :portb6, :portb5, :portb4, :portb3, :portb2, :portb1, :portb0
      model.pins(:portb).endian = :little
      model.add_power_pin :vdd1, voltage: 3, current_limit: 0.05, meta: { min_voltage: 1.5 }
      model.add_power_pin :vdd2
      model.add_power_pin_group :vdd, :vdd1, :vdd2
      model.add_ground_pin :gnd1
      model.add_ground_pin :gnd2
      model.add_ground_pin :gnd3
      model.add_ground_pin_group :gnd, :gnd1, :gnd2, :gnd3

      model.sub_block :block1, file: 'origen/export1/block1.rb', dir: '/scratch/nxa21353/Code/github/origen/vendor/lib/models', lazy: true

    end
  end
end
# rubocop:enable all
