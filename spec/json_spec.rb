require 'spec_helper'

describe 'JSON output' do

  class JSONTop
    include Origen::TopLevel

    def initialize
      sub_block :sub1, class_name: "JSONSub", base_address: 0x2000_0000
      sub_block :sub2, class_name: "JSONSub", base_address: 0x3000_0000
      add_reg :r1, 0
    end
  end

  class JSONSub
    include Origen::Model

    def initialize

      # **The Full Name of the Reg**
      #
      # The description of the reg
      # over a few lines
      reg :reg1, 0x10 do |reg|
        bits 31..16, :upper
        bit 7, :bitx, access: :ro
        bit 6, :bity, reset: 1
        bits 4..3, :bitz, reset: 2, access: :w1c
        # **Mode Ready** - Signals indicating that the analog is ready
        #
        # 0 | Analog voltages have not reached target levels for the specified mode of operation
        # 1 | Analog voltages have reached target levels for the specified mode of operation
        bits 1..0, :aready
      end
    end
  end

  before :all do
    Origen.target.temporary = -> { JSONTop.new }
    Origen.target.load!
  end

  it 'models can convert' do
    dut.to_json.should == (<<-END
{
  "name": null,
  "address": 0,
  "path": "",
  "blocks": [
    {
      "name": "sub1",
      "address": 536870912
    },
    {
      "name": "sub2",
      "address": 805306368
    }
  ],
  "registers": [
    {
      "name": "r1",
      "full_name": null,
      "address": 0,
      "offset": 0,
      "size": 32,
      "path": "r1",
      "reset_value": 0,
      "description": [

      ],
      "bits": [
        {
          "name": "d",
          "full_name": null,
          "position": 0,
          "size": 32,
          "reset_value": 0,
          "access": "rw",
          "description": [

          ],
          "bit_values": [

          ]
        }
      ]
    }
  ]
}
END
).strip
  end

  it 'registers can convert' do
    dut.sub1.reg1.to_json.should == (<<-END
{
  "name": "reg1",
  "full_name": "The Full Name of the Reg",
  "address": 536870928,
  "offset": 16,
  "size": 32,
  "path": "sub1.reg1",
  "reset_value": 80,
  "description": [
    "The description of the reg",
    "over a few lines"
  ],
  "bits": [
    {
      "name": "upper",
      "full_name": null,
      "position": 16,
      "size": 16,
      "reset_value": 0,
      "access": "rw",
      "description": [

      ],
      "bit_values": [

      ]
    },
    {
      "name": "bitx",
      "full_name": null,
      "position": 7,
      "size": 1,
      "reset_value": 0,
      "access": "ro",
      "description": [

      ],
      "bit_values": [

      ]
    },
    {
      "name": "bity",
      "full_name": null,
      "position": 6,
      "size": 1,
      "reset_value": 1,
      "access": "rw",
      "description": [

      ],
      "bit_values": [

      ]
    },
    {
      "name": "bitz",
      "full_name": null,
      "position": 3,
      "size": 2,
      "reset_value": 2,
      "access": "w1c",
      "description": [

      ],
      "bit_values": [

      ]
    },
    {
      "name": "aready",
      "full_name": "Mode Ready",
      "position": 0,
      "size": 2,
      "reset_value": 0,
      "access": "rw",
      "description": [
        "Signals indicating that the analog is ready"
      ],
      "bit_values": [
        {
          "value": 0,
          "description": "Analog voltages have not reached target levels for the specified mode of operation"
        },
        {
          "value": 1,
          "description": "Analog voltages have reached target levels for the specified mode of operation"
        }
      ]
    }
  ]
}
END
).strip
  end
end
