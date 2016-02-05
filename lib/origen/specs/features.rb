module Origen
  module Specs
    # Ruby Data Class that contains Creation Information for the IP Block
    class Features
      # This is the Id of the Feature that will be referenced
      # Future goal is to be able to tie this ID to a specification in a Product Requirements Document
      attr_accessor :id
      
      # Feature Type
      # Current supported types are
      #   intro :: Intro Paragraph for the Features Page
      #   feature :: Main Feature (e.g. Additional peripherals include)
      #   subfeature :: Sub Feature that will be a sub-bullet to feature.  (e.g. Four I2C controllers)
      attr_accessor :type
      
      # Feature Reference
      #  To be used for sub-feature so that they can be linked easily
      attr_accessor :feature_ref
      
      #Applicable Devices for this feature.  This allows for multiple devices from one piece of silicon
      #  If this feature is on Part B and Part D, then applicable devices will include Part B and Part D, but no other parts
      attr_accessor :applicable_devices
      
      # The actual text of the feature
      attr_accessor :text
      
      # Internal comments about this feature.  Why was this feature included here?  Any changes from the 
      # Product Requirements Document
      attr_accessor :internal_comments
      
      # Initialize the Feature to be used
      def initialize(id, attrs, applicable_devices, text, internal_comments)
        @id = id
        @type = attrs[:type]
        @feature_ref = attrs[:feature_ref]
        @applicable_devices = applicable_devices
        @text = text
        @internal_comments = internal_comments
      end
    end # module Features
  end # module Specs
end # module Origen