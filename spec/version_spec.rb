require "spec_helper"

describe Origen::VersionString do

  describe "Timestamp format" do

    it "can be identified as a timestamp" do
      %w(Rel20120203 sm_2012_11_02_22_02 tjc_2014_09_25_15_00).each do |tag|
        Origen::VersionString.new(tag).timestamp?.should == true
        Origen::VersionString.new(tag).semantic?.should == false
      end
    end

    it "identifies production tags" do
      %w(Rel20120203 Rel20131212).each do |tag|
        Origen::VersionString.new(tag).production?.should == true
        Origen::VersionString.new(tag).development?.should == false
      end
    end

    it "identifies development tags" do
      %w(sm_2012_11_02_22_02 th_2013_12_23_00 blah_blah_some_tag).each do |tag|
        Origen::VersionString.new(tag).development?.should == true
        Origen::VersionString.new(tag).production?.should == false
      end
    end

    describe "condition_met? method" do

      it "equal works" do
        ref = Origen::VersionString.new("sm_2012_11_02_22_02")
        ref.condition_met?("sm_2012_11_02_22_02").should == true
        ref.condition_met?("= sm_2012_11_02_22_02").should == true
        ref.condition_met?("== sm_2012_11_02_22_02").should == true
        ref.condition_met?("sm_2013_11_02_22_02").should == false
        ref.condition_met?("sm_2012_10_02_22_02").should == false
        ref.condition_met?("sm_2012_11_01_22_02").should == false
        ref.condition_met?("sm_2012_11_02_12_02").should == false
        ref.condition_met?("sm_2012_11_02_22_05").should == false
      end

      it "greater than works" do
        ref = Origen::VersionString.new("sm_2012_11_02_22_02")
        ref.condition_met?(" > sm_2012_11_02_22_02").should == false

        ref.condition_met?(" > sm_2011_11_02_22_02").should == true
        ref.condition_met?(" > sm_2013_11_02_22_02").should == false
        ref.condition_met?("> sm_2012_10_02_22_02").should == true
        ref.condition_met?(">sm_2012_12_02_22_02").should == false
        ref.condition_met?(">sm_2012_11_01_22_02").should == true
        ref.condition_met?(">sm_2012_11_03_22_02").should == false
        ref.condition_met?(">sm_2012_11_02_21_02").should == true
        ref.condition_met?(">sm_2012_11_02_23_02").should == false
        ref.condition_met?(">sm_2012_11_02_22_01").should == true
        ref.condition_met?("> sm_2012_11_02_22_03").should == false
        ref.condition_met?("> Rel20121101").should == true
        ref.condition_met?("> Rel20121102").should == false  # Assume the negative in this case
        ref.condition_met?(">Rel20121103").should == false
      end

      it "greater than equal works" do
        ref = Origen::VersionString.new("sm_2012_11_02_22_02")
        ref.condition_met?(">= sm_2012_11_02_22_02").should == true
        ref.condition_met?(">= Rel20121102").should == false  # Assume the negative in this case
      end

      it "less than works" do
        ref = Origen::VersionString.new("sm_2012_11_02_22_02")
        ref.condition_met?(" < sm_2012_11_02_22_02").should == false

        ref.condition_met?(" < sm_2011_11_02_22_02").should == false
        ref.condition_met?(" < sm_2013_11_02_22_02").should == true
        ref.condition_met?("< sm_2012_10_02_22_02").should == false
        ref.condition_met?("<sm_2012_12_02_22_02").should == true
        ref.condition_met?("<sm_2012_11_01_22_02").should == false
        ref.condition_met?("<sm_2012_11_03_22_02").should == true
        ref.condition_met?("<sm_2012_11_02_21_02").should == false
        ref.condition_met?("<sm_2012_11_02_23_02").should == true
        ref.condition_met?("< sm_2012_11_02_22_01").should == false
        ref.condition_met?("< sm_2012_11_02_22_03").should == true
        ref.condition_met?("< Rel20121101").should == false
        ref.condition_met?("< Rel20121102").should == false  # Assume the negative in this case
        ref.condition_met?("<Rel20121103").should == true
      end

      it "less than equal works" do
        ref = Origen::VersionString.new("sm_2012_11_02_22_02")
        ref.condition_met?("<= sm_2012_11_02_22_02").should == true
        ref.condition_met?("<= Rel20121102").should == false  # Assume the negative in this case
      end

      it "production works" do
        Origen::VersionString.new("Rel20121102").condition_met?(:production).should == true
        Origen::VersionString.new("Rel20121102").condition_met?("production").should == true
        Origen::VersionString.new("Rel20121102").condition_met?(:prod).should == true
        Origen::VersionString.new("sm_2012_11_02_22_02").condition_met?(:production).should == false
        Origen::VersionString.new("sm_2012_11_02_22_02").condition_met?("production").should == false
        Origen::VersionString.new("sm_2012_11_02_22_02").condition_met?(:prod).should == false
      end

      it "latest works in a comparison" do
        ref = Origen::VersionString.new("sm_2012_11_02_22_02")
        ref.condition_met?(" > Trunk").should == false
        ref.condition_met?(" > Latest").should == false
        ref.condition_met?(" >= Trunk").should == false
        ref.condition_met?(" >= Latest").should == false
        ref.condition_met?(" < Trunk").should == true
        ref.condition_met?(" < Latest").should == true
        ref.condition_met?(" <= Trunk").should == true
        ref.condition_met?(" <= Latest").should == true
      end

    end

  end

  describe "Semantic format" do

    it "can be identified as semantic" do
      %w(v1.2.3 v1.2.3.dev3 1.2.3 1.3.0.pre1).each do |tag|
        Origen::VersionString.new(tag).timestamp?.should == false
        Origen::VersionString.new(tag).semantic?.should == true
      end
    end

    it "identifies production tags" do
      %w(v2.1.0 v2.0.0 v1.10.10 1.2.3).each do |tag|
        Origen::VersionString.new(tag).production?.should == true
        Origen::VersionString.new(tag).development?.should == false
      end
    end

    it "identifies development tags" do
      %w(v2.0.1.dev01 v2.1.1.dev57 1.2.3.pre10).each do |tag|
        Origen::VersionString.new(tag).development?.should == true
        Origen::VersionString.new(tag).production?.should == false
      end
    end

    describe "condition_met? method" do

      it "equal works" do
        ref = Origen::VersionString.new("v2.2.2")
        (ref == " v2.2.2").should == true
        (ref == "v2.2.2").should == true
        (ref == "v2.2.2").should == true
        (ref == "v1.2.2").should == false
        (ref == "v2.1.2").should == false
        (ref == "v2.2.1").should == false
        (ref == "v2.2.2.dev2").should == false
        ref = Origen::VersionString.new("2.2.2")
        (ref == " 2.2.2").should == true
        (ref == "2.2.2").should == true
        (ref == "2.2.2").should == true
        (ref == "1.2.2").should == false
        (ref == "2.1.2").should == false
        (ref == "2.2.1").should == false
        (ref == "2.2.2.pre2").should == false
      end

      it "greater than works" do
        ref = Origen::VersionString.new("v2.2.2")
        (ref > " v2.2.2").should == false

        (ref > " v1.2.2").should == true
        (ref > " v3.2.2").should == false
        (ref > "v2.1.2").should == true
        (ref > "v2.3.2").should == false
        (ref > "v2.2.1").should == true
        (ref > "v2.2.3").should == false
        (ref > " v2.2.1.dev2").should == true
        (ref > " v2.2.2.dev2").should == false

        ref = Origen::VersionString.new("2.2.2")
        (ref > " 2.2.2").should == false

        (ref > " 1.2.2").should == true
        (ref > " 3.2.2").should == false
        (ref > "2.1.2").should == true
        (ref > "2.3.2").should == false
        (ref > "2.2.1").should == true
        (ref > "2.2.3").should == false
        (ref > " 2.2.1.dev2").should == true
        (ref > " 2.2.2.dev2").should == false
      end

      it "greater than equal works" do
        ref = Origen::VersionString.new("v2.2.2")
        (ref >= "v2.2.2").should == true
        ref = Origen::VersionString.new("2.2.2")
        (ref >= "2.2.2").should == true
      end

      it "less than works" do
        ref = Origen::VersionString.new("v2.2.2")
        (ref > "v2.2.2").should == false

        (ref < "v1.2.2").should == false
        (ref < "v3.2.2").should == true
        (ref < "v2.1.2").should == false
        (ref < "v2.3.2").should == true
        (ref < "v2.2.1").should == false
        (ref < "v2.2.3").should == true
        (ref < "v2.2.1.dev2").should == false
        (ref < "v2.2.2.dev2").should == true

        ref = Origen::VersionString.new("2.2.2")
        (ref > "2.2.2").should == false

        (ref < "1.2.2").should == false
        (ref < "3.2.2").should == true
        (ref < "2.1.2").should == false
        (ref < "2.3.2").should == true
        (ref < "2.2.1").should == false
        (ref < "2.2.3").should == true
        (ref < "2.2.1.dev2").should == false
        (ref < "2.2.2.dev2").should == true

        (Origen::VersionString.new('0.10.0') < Origen::VersionString.new('0.8.0')).should == false
      end

      it "less than equal works" do
        ref = Origen::VersionString.new("v2.2.2")
        (ref <= "v2.2.2").should == true
        ref = Origen::VersionString.new("2.2.2")
        (ref <= "2.2.2").should == true
      end

      it "production works" do
        Origen::VersionString.new("v1.2.3").condition_met?(:production).should == true
        Origen::VersionString.new("v1.2.3").condition_met?("production").should == true
        Origen::VersionString.new("v1.2.3").condition_met?(:prod).should == true
        Origen::VersionString.new("v1.2.3.dev1").condition_met?(:production).should == false
        Origen::VersionString.new("v1.2.3.dev1").condition_met?("production").should == false
        Origen::VersionString.new("v1.2.3.dev1").condition_met?(:prod).should == false

        Origen::VersionString.new("1.2.3").condition_met?(:production).should == true
        Origen::VersionString.new("1.2.3").condition_met?("production").should == true
        Origen::VersionString.new("1.2.3").condition_met?(:prod).should == true
        Origen::VersionString.new("1.2.3.pre1").condition_met?(:production).should == false
        Origen::VersionString.new("1.2.3.pre1").condition_met?("production").should == false
        Origen::VersionString.new("1.2.3.pre1").condition_met?(:prod).should == false
      end

      it "latest works in a comparison" do
        ref = Origen::VersionString.new("v2.2.2")
        ref.condition_met?(" > Trunk").should == false
        ref.condition_met?(" > Latest").should == false
        ref.condition_met?(" < Trunk").should == true
        ref.condition_met?(" < Latest").should == true

        ref = Origen::VersionString.new("2.2.2")
        ref.condition_met?(" > Trunk").should == false
        ref.condition_met?(" > Latest").should == false
        ref.condition_met?(" < Trunk").should == true
        ref.condition_met?(" < Latest").should == true
      end

      it "components can be extracted" do
        ref = Origen::VersionString.new("v1.2.3")
        ref.major.should == 1
        ref.minor.should == 2
        ref.bugfix.should == 3
        ref.pre.should == nil

        ref = Origen::VersionString.new("1.2.3")
        ref.major.should == 1
        ref.minor.should == 2
        ref.bugfix.should == 3
        ref.pre.should == nil

        ref = Origen::VersionString.new("11.20.3.pre20")
        ref.major.should == 11
        ref.minor.should == 20
        ref.bugfix.should == 3
        ref.pre.should == 20
        ref.dev.should == 20
      end

      it "next number generation works" do
        S = Origen::VersionString
        S.new("1.2.3").next_dev.should == "1.3.0.pre0"
        S.new("1.2.3").next_dev(:tiny).should == "1.2.4.pre0"
        S.new("1.2.3").next_dev(:major).should == "2.0.0.pre0"
        S.new("1.2.3").next_prod.should == "1.3.0"
        S.new("1.2.3").next_prod(:tiny).should == "1.2.4"
        S.new("1.2.3").next_prod(:major).should == "2.0.0"
        # If already on a pre-release cycle just increment it, if a user wants
        # to switch the target prod version they must do it manually
        S.new("1.2.0.pre1").next_dev.should == "1.2.0.pre2"
        S.new("1.2.0.pre1").next_dev(:tiny).should == "1.2.0.pre2"
        S.new("1.2.0.pre1").next_dev(:major).should == "1.2.0.pre2"
        S.new("1.2.0.pre1").next_prod.should == "1.2.0"
        S.new("1.2.0.pre1").next_prod(:tiny).should == "1.2.0"
        S.new("1.2.0.pre1").next_prod(:major).should == "1.2.0"
        # Special case to handle the conversion of existing .dev tags which have
        # historically been behind the prod tag it is targeting
        S.new("1.2.3.dev2").next_dev.should == "1.3.0.pre3"
        S.new("1.2.3.dev2").next_dev(:minor).should == "1.3.0.pre3"
        S.new("1.2.3.dev2").next_dev(:tiny).should == "1.3.0.pre3"
        S.new("1.2.3.dev2").next_prod.should == "1.3.0"
        S.new("1.2.3.dev2").next_prod(:tiny).should == "1.2.4"
        S.new("1.2.3.dev2").next_prod(:major).should == "2.0.0"
      end
    end

    it 'can be compared to regular text strings' do
      S = Origen::VersionString
      (S.new('master') == 'HEAD').should == false
      (S.new('master') == S.new('HEAD')).should == false
      ('master' == S.new('HEAD')).should == false
    end

    specify "the minimum_version method works" do
      Origen::VersionString.minimum_version("v1.2.3").should == "1.2.3"
      Origen::VersionString.minimum_version("== v1.2.3").should == "1.2.3"
      Origen::VersionString.minimum_version(">= v1.2.5").should == "1.2.5"
      Origen::VersionString.minimum_version("< v1.2.5").should == nil
      Origen::VersionString.minimum_version("<= v1.2.5").should == nil

      Origen::VersionString.minimum_version("1.2.3").should == "1.2.3"
      Origen::VersionString.minimum_version("== 1.2.3").should == "1.2.3"
      Origen::VersionString.minimum_version(">= 1.2.5").should == "1.2.5"
      Origen::VersionString.minimum_version("< 1.2.5").should == nil
      Origen::VersionString.minimum_version("<= 1.2.5").should == nil
    end

    specify "the maximum_version method works" do
      Origen::VersionString.maximum_version("v1.2.3").should == "1.2.3"
      Origen::VersionString.maximum_version("== v1.2.3").should == "1.2.3"
      Origen::VersionString.maximum_version("> v1.2.4").should == nil
      Origen::VersionString.maximum_version(">= v1.2.5").should == nil
      Origen::VersionString.maximum_version("<= v1.2.5").should == "1.2.5"

      Origen::VersionString.maximum_version("1.2.3").should == "1.2.3"
      Origen::VersionString.maximum_version("== 1.2.3").should == "1.2.3"
      Origen::VersionString.maximum_version("> 1.2.4").should == nil
      Origen::VersionString.maximum_version(">= 1.2.5").should == nil
      Origen::VersionString.maximum_version("<= 1.2.5").should == "1.2.5"
    end

  end
end
