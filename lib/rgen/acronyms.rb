require 'active_support/core_ext/string/inflections'
# This helps the String inflection methods work correctly with our acronyms
#
#   "MPGBOMApp".underscore    # => "mpg_bom_app"
#   "mpg_bom_app".camelcase   # => "MPGBOMApp"
ActiveSupport::Inflector.inflections(:en) do |inflect|
  inflect.acronym 'RGen'
  inflect.acronym 'SVN'

  inflect.acronym 'MPG'
  inflect.acronym 'AMPG'
  inflect.acronym 'DNG'     # Digital Networking Group
  inflect.acronym 'NVM'

  inflect.acronym 'C90TFS'
  inflect.acronym 'C40TFS'
  inflect.acronym 'C28TFS'
  inflect.acronym 'C90'
  inflect.acronym 'C40'
  inflect.acronym 'C28'

  inflect.acronym 'TFS'
  inflect.acronym 'SGF'

  inflect.acronym 'BOM'     # Bill of Materials
  inflect.acronym 'CATI'
  inflect.acronym 'RTL'
  inflect.acronym 'FSL'     # Freescale
  inflect.acronym 'PDM'

  inflect.acronym 'IP'      # Intellectual Property
  inflect.acronym 'SoC'     # System on Chip
  inflect.acronym 'SOC'     # System on Chip
  inflect.acronym 'DUT'     # Device Under Test
  inflect.acronym 'ADC'
  inflect.acronym 'ATD'
  inflect.acronym 'RAM'
  inflect.acronym 'PLL'     # Phase Locked Loop
  inflect.acronym 'ATX'
  inflect.acronym 'BIST'    # Built-In Self Test
  inflect.acronym 'FSLBIST' # Freescale Built-In Self Test
  inflect.acronym 'MBIST'   # Memory BIST
  inflect.acronym 'ARM'
  inflect.acronym 'DFT'     # Design for Test
  inflect.acronym 'VCO'
  inflect.acronym 'DDR'
  inflect.acronym 'JTAG'
  inflect.acronym 'LTG'     # Lynx Test Guide
  inflect.acronym 'DTG'     # DDR Test Guide
  inflect.acronym 'DIB'     # Device Interface Board

  inflect.acronym 'S08'
  inflect.acronym 'LAU'     # Least Addressible Unit
  inflect.acronym 'LSB0'    # Least Significant Bit 0
  inflect.acronym 'MSB0'    # Most Significant Bit 0
  inflect.acronym 'PDE'     # Product Development Engineering
  inflect.acronym 'NPI'     # New Product Introduction

  inflect.acronym 'ML'  # Markup Language
end
