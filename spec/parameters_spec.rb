require 'spec_helper'

module ParametersSpec

  describe "Parameters" do

    class DUT
      include Origen::TopLevel

      def initialize
        define_params :default do |params|
          params.tprog = 20
          params.erase.time = 4
          params.erase.pulses = pulses
          params.test.ac.period = 10.ns
          params.test.func = -> { 2 * 2 }
          params.vdd.nom = 1
          params.vdd.min = 0.8
          params.vdd.max = 1.2
        end

        define_params :ate, inherit: :default do |params|
          params.tprog = 30
          params.erase.pulses = 4
          params.test.func = -> { 2 * 3 }
          params.vdd.min = 0.7
        end

        define_params :probe, inherit: :ate do |params|
          params.erase.time = 3
          params.tprog = 40
        end

        define_params :ft, inherit: :ate do |params|
          params.test.ac.period = 15.ns
          params.test.func = -> { 2 * 4 }
        end

        @y = 20
        define_params :set1 do |params|
          params.x = 10
          params.y = @y
        end

        define_params :set2, inherit: :set1 do |params, parent|
          params.x = parent.x * 2
          params.y = @y * 2
        end

        define_params :set3, inherit: :set2 do |params, parent|
          params.x = parent.x * 2
          params.y = @y * 4
        end

        reg :erase, 0x0 do
          bits 7..4, :time, bind: params.live.erase.time
          bits 3..0, :pulses
        end
        sub_block :ip_with_params, class_name: 'IpWithParams', base_address: 0xDEAD_BEEF
      end

      def pulses
        5
      end

      def extend
        define_params :default do |params|
          params.tprog = 30
          params.test2.blah = 40
        end
      end
    end
  
    class IpWithParams
      include Origen::Model
      
      def initialize 
        define_params :default, inherit: 'dut.default' do |params|
          params.erase.time = 5
          params.vdd.xmin = 0.7
        end
      end  
    end
    
    before :each do
      Origen.app.unload_target!
      $dut = DUT.new
    end

    it 'Parameters can be accessed via an explicit context' do
      $dut.params.tprog.should == 20
      $dut.params(:ate).tprog.should == 30
      $dut.params(:probe).tprog.should == 40
      $dut.params.test.ac.period.should == 10.ns
      $dut.params(:ft).test.ac.period.should == 15.ns
    end

    it "Min and max parameter names don't act funny" do
      $dut.params.vdd.nom.should == 1
      $dut.params.vdd.min.should == 0.8
      $dut.params.vdd.max.should == 1.2
      $dut.params = :ate
      $dut.params.vdd.min.should == 0.7
    end

    it "Defined values can be extracted" do
      $dut.params.tprog.should == 20
      $dut.params.erase.time.should == 4
      $dut.params.test.ac.period.should == 10.ns
    end

    it "param sets cannot be re-opened" do
      -> { $dut.extend }.should raise_error
    end

    it "params cannot be modified or added outside of a define block" do
      -> { $dut.params.tprog = 30 }.should raise_error
      -> { $dut.params[:tprog] = 30 }.should raise_error
      -> { $dut.params[:tprog2] = 30 }.should raise_error
      -> { $dut.params.erase.time = 30 }.should raise_error
      -> { $dut.params.erase.time2 = 30 }.should raise_error
      -> { $dut.params.erase[:time] = 30 }.should raise_error
      -> { $dut.params.erase[:time2] = 30 }.should raise_error
    end

    it "Works with local method calls in the defines" do
      $dut.params.erase.pulses.should == 5
    end

    it "current param set can be changed" do
      $dut.params.tprog.should == 20
      $dut.params = :probe
      $dut.params.tprog.should == 40
    end

    it "Setting the params to an unknown set will raise an error" do
      $dut.params = :erase  # You are allowed to set it, since this may mean something
                            # to another object that follows this one for context
      $dut.params.context.should == :erase
      # But you can't access it
      -> { $dut.params.tprog }.should raise_error
    end

    it "inherited values work" do
      $dut.params.tprog.should == 20
      $dut.params.erase.time.should == 4
      $dut.params.erase.pulses.should == 5
      $dut.params.test.ac.period.should == 10.ns
      $dut.params = :ate
      $dut.params.tprog.should == 30
      $dut.params.erase.time.should == 4
      $dut.params.erase.pulses.should == 4
      $dut.params.test.ac.period.should == 10.ns
      $dut.params = :probe
      $dut.params.tprog.should == 40
      $dut.params.erase.time.should == 3
      $dut.params.erase.pulses.should == 4
      $dut.params.test.ac.period.should == 10.ns
      $dut.params = :ft
      $dut.params.tprog.should == 30
      $dut.params.erase.time.should == 4
      $dut.params.erase.pulses.should == 4
      $dut.params.test.ac.period.should == 15.ns
    end

    it "with_params method works" do
      $dut.params.tprog.should == 20
      $dut.params.context.should == :default
      $dut.with_params :probe do
        $dut.params.context.should == :probe
        $dut.params.tprog.should == 40
      end
      $dut.params.context.should == :default
      $dut.params.tprog.should == 20
    end

    it "function parameters work" do
      $dut.params.test.func.should == 4
      $dut.params.test[:func].should == 4
      $dut.params = :ate
      $dut.params.test.func.should == 6
      $dut.params = :ft
      $dut.params.test.func.should == 8
      $dut.params.test.each do |name, val|
        if name == :func
          val.should == 8
        end
      end
    end

    it "live updating references can be created" do
      t = $dut.params.live.test.ac.period
      t.is_a_live_parameter?.should == true
      t.should == 10.ns
      $dut.params = :ft
      t.should == 15.ns
      $dut.params = :default
      t.should == 10.ns
    end

    it "Can bind to register bit values" do
      $dut.erase.pulses.bind $dut.params.live.erase.pulses
      $dut.erase.data.should == 0x45
      $dut.params = :probe
      $dut.erase.data.should == 0x34
      $dut.params = :default
      $dut.erase.time.data.should == 4
      $dut.erase.pulses.data.should == 5
      $dut.params = :probe
      $dut.erase.time.data.should == 3
      $dut.erase.pulses.data.should == 4

      lambda { $dut.erase.pulses.bind $dut.params.erase.pulses }.should raise_error
    end

    it "inherited value works" do
      $dut.params = :set1
      $dut.params.x.should == 10
      $dut.params.y.should == 20
      $dut.params = :set2
      $dut.params.x.should == 20
      $dut.params.y.should == 40
      $dut.params = :set3
      $dut.params.x.should == 40
      $dut.params.y.should == 80
    end

    it "parameter context can be proxied to dut" do
      class IP1
        include Origen::Model
        parameters_context :top

        def initialize
          define_params :default do |params|
            params.a = 20
          end
          define_params :ate do |params|
            params.a = 30
          end
        end
      end

      ip = IP1.new
      $dut.params = :default
      ip.params.a.should == 20
      $dut.params = :ate
      ip.params.a.should == 30
    end

    it "parameter context can be proxied to another object" do
      class IP2
        include Origen::Model
        parameters_context "ip3"

        def initialize
          define_params :default do |params|
            params.a = 20
          end
          define_params :ate do |params|
            params.a = 30
          end
        end

        def ip3
          @ip3 ||= IP3.new
        end
      end

      class IP3
        include Origen::Model
      end

      ip = IP2.new
      ip.params.context.should == :default
      ip.params.a.should == 20
      ip.ip3.params = :ate
      ip.params.context.should == :ate
      ip.params.a.should == 30
    end
    
    it "parameter sets can be converted to a flat hash" do
      $dut.params.to_flat_hash.include?('erase.time').should == true
      $dut.params.to_flat_hash['test.ac.period'].should == 1e-08
      $dut.params.to_flat_hash(delimiter: '_').include?('erase_time').should == true
      $dut.params.to_flat_hash(delimiter: '_')['test_ac_period'].should == 1e-08
    end
    
    it "all available parameter contexts can be returned as an array" do
      $dut.params.available_contexts.should == [:default, :ate, :probe, :ft, :set1, :set2, :set3]
      $dut.params.contexts.should == [:default, :ate, :probe, :ft, :set1, :set2, :set3]
    end
    
    it "objects that own parameter sets can tell if they do or not" do
      $dut.has_params?.should == true
    end
    
    it 'can pass inheritance between objects' do
      $dut.params.contexts.should == [:default, :ate, :probe, :ft, :set1, :set2, :set3]
      $dut.ip_with_params.params.contexts.should == [:default]
      $dut.params(:default).keys.should == [:tprog, :erase, :test, :vdd]
      $dut.ip_with_params.params(:default).keys.should == [:tprog, :erase, :test, :vdd]
      $dut.params(:default).vdd.keys.should == [:nom, :min, :max]
      $dut.ip_with_params.params(:default).vdd.keys.should == [:nom, :min, :max, :xmin]
      ($dut.ip_with_params.params(:default).vdd.keys - $dut.params(:default).vdd.keys).should == [:xmin]
      $dut.ip_with_params.params(:default).vdd.xmin.should == 0.7
      $dut.params(:default).erase.time.should == 4
      $dut.ip_with_params.params(:default).erase.time.should == 5
    end
  end
end
