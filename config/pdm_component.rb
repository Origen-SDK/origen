class RGenCoreApplication
  # An instance of this class is pre-instantiated at: RGen.app.pdm_component
  class PDMComponent

    include RGen::PDM

    def initialize(options={})
      @pdm_use_test_system = false
      @pdm_initial_version_number = 14

      @pdm_part_name = "RGen"
      @pdm_part_type = "software"
      @pdm_vc_type = "generator"
      @pdm_functional_category = "software|unclassifiable"
      @pdm_version = RGen.version
      @pdm_support_analyst = "Stephen McGinty (r49409)"
      @pdm_security_owner = "Stephen McGinty (r49409)"
      @pdm_owner = "Stephen McGinty (r49409);Daniel Hadad (ra6854)"
      @pdm_design_manager = "Wendy Malloch (ttz231)"
      @pdm_cm_version = RGen.version
      @pdm_cm_path = "sync://sync-15088:15088/Projects/common_tester_blocks/rgen"
    end

  end
end
module RGenCore
  PDMComponent = RGenCoreApplication::PDMComponent
end
