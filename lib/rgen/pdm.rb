module RGen
  module PDM
    autoload :WebService, 'rgen/pdm/web_service'
    autoload :PI, 'rgen/pdm/pi'
    autoload :Tracker, 'rgen/pdm/tracker'

    require 'rgen/pdm/attributes'

    include Attributes

    # Set true to use the PDM test system rather than the live system.
    # The test system can be found at: http://designpdmtest.freescale.net/Agile
    attr_accessor :pdm_use_test_system

    # This should be set to the PDM version number that the current object represents.
    # For example if the object represents C90TFS_NVM_tester_010, then set this
    # attribute to 10.
    #
    # This attribute is required to be set when including a component in a BOM, otherwise
    # it is not required to be set when releasing a new version.
    #
    # It can also be set to :latest to pick up the latest version number for the component.
    attr_accessor :pdm_version_number

    # Set this attribute to create a branch point release from the given version. If this
    # attribute is not set then all releases will simply supercede the last release.
    attr_accessor :pdm_branch_version_number

    # Set this to specify which version the new release should supercede.
    # If un-specified the new release will automatically supercede the last version on the
    # trunk.
    attr_accessor :pdm_supercedes_version_number

    # Set this attribute to include components in the BOM, it should be set to an array
    # of objects, each of which must also include the RGen::PDM module and have the
    # pdm_version_number attribute set.
    attr_accessor :pdm_bom

    # If you begin automating PDM releases on a component that already exists on PDM, then
    # you must set this attribute to let RGen know what the latest part number is on PDM.
    #
    # For example if the latest component is called C90TFS_NVM_tester_010 at the time of
    # setting up the component in RGen then set this attribute to 10.
    #
    # If the object does not exist on PDM yet then you can leave this blank and RGen will
    # create and begin tracking the component from the initial version.
    attr_accessor :pdm_initial_version_number

    attr_accessor :pdm_meta_tags

    def self.update_ticket(tkt)
      pdm_pi.update_ticket(tkt)
    end

    def self.pdm_pi(_options = {})
      @pdm_pi ||= PI.new(use_test_system: true)
    end

    def pdm_base_url
      if pdm_use_test_system
        host = 'http://designpdmtest.freescale.net'
      else
        host = 'http://designpdm.freescale.net'
      end
    end

    # Returns the url for specific component version on PDM, i.e. if the model represents
    # pdm component C90TFS_NVM_tester_010 then the link to that component version will be
    # returned
    def pdm_url
      "#{pdm_base_url}/Agile/object/#{pdm_part_type}/#{pdm_part_number}"
    end

    # Returns the url for component's item group on PDM, i.e. if the model represents
    # pdm component C90TFS_NVM_tester_010 then the link to C90TFS_NVM_tester will be
    # returned
    def pdm_item_group_url
      "#{pdm_base_url}/Agile/object/Item Group/#{pdm_part_name}"
    end

    # The PI API, returns an instance of RGen::PDM::PI
    def pdm_pi
      @pdm_pi ||= PI.new(use_test_system: pdm_use_test_system)
    end

    # The PDM Web Service API, returns an instance of RGen::PDM::WebService
    def pdm_web_service
      @pdm_web_service ||= WebService.new
    end

    # When talking to PDM we need to use the 'Part Number' which is comprised
    # of the part name plus a numeric revision.
    #
    # For example 'C90TFS_NVM_tester' is the part name, 'C90TFS_NVM_tester_058' is a
    # possible part number.
    def pdm_part_number
      pdm_part_name + '_%03d' % _pdm_version_number
    end

    def pdm_branch_part_number
      if pdm_branch_version_number
        pdm_part_name + '_%03d' % pdm_branch_version_number
      end
    end

    # Returns the latest part number regardless of whether it is on a branch or not
    def pdm_latest_part_number
      if pdm_latest_version_number
        pdm_part_name + '_%03d' % pdm_latest_version_number
      end
    end

    # Returns the latest part number that is not on a branch
    def pdm_latest_trunk_part_number
      if pdm_latest_trunk_version_number
        pdm_part_name + '_%03d' % pdm_latest_trunk_version_number
      end
    end

    def pdm_supercedes_part_number
      if pdm_supercedes_version_number
        pdm_part_name + '_%03d' % pdm_supercedes_version_number
      end
    end

    def pdm_bom
      []
    end

    def pdm_meta_tags
      []
    end

    def _pdm_version_number
      if pdm_version_number && pdm_version_number != :latest
        pdm_version_number
      else
        pdm_latest_version_number ||
          fail("You must set the pdm_version_number attribute of #{self.class}")
      end
    end

    def pdm_latest_version_number
      if pdm_tracker.latest_version_number
        if pdm_initial_version_number &&
           pdm_initial_version_number > pdm_tracker.latest_version_number
          pdm_initial_version_number
        else
          pdm_tracker.latest_version_number
        end
      else
        pdm_initial_version_number
      end
    end

    def pdm_latest_trunk_version_number
      if pdm_tracker.latest_trunk_version_number
        if pdm_initial_version_number &&
           pdm_initial_version_number > pdm_tracker.latest_trunk_version_number
          pdm_initial_version_number
        else
          pdm_tracker.latest_trunk_version_number
        end
      else
        pdm_initial_version_number
      end
    end

    def pdm_supercedes_version_number
      @pdm_supercedes_version_number || pdm_latest_trunk_version_number
    end

    def pdm_component_binding
      binding
    end

    def pdm_tracker
      @pdm_tracker ||= Tracker.new(component: self)
    end

    # Pulls the BOM from PDM into an array of hashes with the following keys:
    #
    # * :pdm_part_name (e.g. C90TFS_NVM_tester)
    # * :pdm_version_number  (e.g. 058 (actually returned as 58))
    # * :pdm_version (e.g. Rel20121002)
    def pdm_remote_bom
      pdm_pi.catbom(self)
    end

    # Release a new component version to PDM
    def pdm_release!(options = {})
      options = {
        release_bom: false
      }.merge(options)
      ret = pdm_pi.release!(self)
      pdm_tracker.release!
      ret
    end

    # This method is called before permanently saving a released component in the store,
    # override it to set instance variables for anything you wish to save.
    #
    # Normally it is best to assign the result of any pdm attributes that come from
    # methods as instance variables so that the current state of the component can
    # be reconstructed later.
    def freeze
    end

    def pdm_prepare_for_store
      freeze
      # Clear these so as not to waste effort Marshalling them
      @pdm_pi = nil
      @pdm_web_service = nil
      @pdm_tracker = nil
      @pi_attributes = nil
    end
  end
end
