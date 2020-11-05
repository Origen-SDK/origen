require_relative './chip_package/viewer.rb'
module Origen
  # Represents an SoC Package option
  class ChipPackage
    attr_accessor :description
    attr_reader :viewer
    attr_writer :name
    alias_writer :full_name, :name
    # Returns the owner that $owns the mode (the SoC instance usually)
    attr_accessor :owner

    def initialize(id, options = {})
      @id = id
      @owner = options[:owner]
    end

    def init_viewer(options = {})
      if owner.pins.nil?
        Origen.log.error "Cannot initialize the '#{id}' package viewer, no pins modeled!"
        fail
      end
      ChipPackageViewer.new self, options
    end

    def name
      @name || @id
    end
    alias_method :full_name, :name

    def id
      @id || name.to_s.downcase.gsub(/(\s|-)+/, '_').to_sym
    end

    def id=(val)
      @id = val.to_s.gsub(/(\s|-)+/, '_').downcase.to_sym
    end

    def to_s
      id.to_s
    end

    def to_sym
      to_s.to_sym
    end
  end
end
