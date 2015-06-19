require 'spec_helper'

describe Hash do
  it 'should have indifferent access' do
    h = { 'one' => 1, two: 2 }.with_indifferent_access
    h['one'].should == 1
    h[:one].should == 1
    h['two'].should == 2
    h[:two].should == 2
  end

  it 'can update only the common keys between two hashes' do
    hash_to_update = {
      path:          '.',
      reference_dir: '.',
      clean:         false,
      target:        nil,
      location:      'local',
      recursive:     false,
      output:        '.'
    }

    orig_keys = hash_to_update.keys

    hash_with_new_values = {
      path:           '/homedir/bin',
      clean:          true,
      recursive:      false,
      location:       'lsf',
      key_not_wanted: 'blah'
    }

    hash_to_update.update_common(hash_with_new_values)

    hash_to_update[:path].should == '/homedir/bin'
    hash_to_update[:reference_dir].should == '.'
    hash_to_update[:clean].should == true
    hash_to_update[:target].should.nil?
    hash_to_update[:location].should == 'lsf'
    hash_to_update[:recursive].should == false
    hash_to_update[:output].should == '.'

    hash_to_update.keys.should == orig_keys
    (hash_to_update.key? :key_not_wanted).should == false
  end

  it 'can check for key intersection between two hashes' do
    hash_caller = {
      path:          '.',
      reference_dir: '.',
      clean:         false,
      target:        nil,
      location:      'local',
      recursive:     false,
      output:        '.'
    }

    hash_no_intersection = {
      key_not_wanted: 'blah'
    }

    hash_with_intersection = {
      reference_dir: '..',
      location:      'lsf',
    }

    hash_caller.intersect?(hash_no_intersection).should == false
    hash_caller.intersections(hash_no_intersection).should == []
    hash_caller.intersect?(hash_with_intersection).should == true
    hash_caller.intersections(hash_with_intersection).should == [:reference_dir, :location]
  end

  it 'can filter keys using any type of argument' do
    to_be_filtered_hash = {
      vdd: "1.0V",
      avdd_pll: "1.5V",
      g1vdd: "1.8V",
      g2vdd: "1.35V",
      'bacvdd' => '-1V'
    }
    to_be_filtered_hash.filter(/^g\d\S+/).size.should == 2
    to_be_filtered_hash.filter(/^g\d\S+/).values.should == ["1.8V","1.35V"]
    to_be_filtered_hash.filter(nil).should == to_be_filtered_hash
    to_be_filtered_hash.filter(/^\d+/).should == {}
    to_be_filtered_hash.filter(/\d+/).values.should == ["1.8V","1.35V"]
    to_be_filtered_hash.filter(:vdd).values.first.should == "1.0V"
    to_be_filtered_hash.filter('vdd').should == to_be_filtered_hash
    to_be_filtered_hash.filter(2).values.first.should == "1.35V"
    to_be_filtered_hash.filter('bacvdd').values.first.should == '-1V'
  end

  it 'can find the longest key and the longest value in the hash' do
    myhash = {
      vdd: "1.0V",
      avdd_pll: "1.5V",
      g1vdd: "1.8V",
      g2vdd: "1.35V"
    }
    myhash.longest_key.should == 'avdd_pll'
    myhash.longest_value.should == '1.35V'
  end
end
