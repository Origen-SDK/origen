require 'spec_helper'

describe Enumerable do
  it 'can create lists of primatives or a mix of complex objects' do
    Dog = Struct.new(:breed, :color, :sex)
    multid_hash = {
      '1' => {
        '6' => nil,
        '7' => '',
        '8' => '',
        '1' => 'Value1',
        '2' => '',
        '3' => 'Value2',
        '4' => '',
        '5' => '' },
      '2' => {
        '6' => :cat,
        '7' => '',
        '8' => 'Value3',
        '1' => '',
        '2' => '',
        '3' => Dog.new('Cocker Spaniel', 'Brown', 'Male'),
        '4' => '',
        '5' => '' },
      '3' => {
        '6' => [1, :bird, 3],
        '7' => '',
        '8' => Dog.new('Pitbull', 'Albino',  'Female'),
        '1' => [],
        '2' => '',
        '3' => nil,
        '4' => '',
        '5' => '' },
      '4' => {
        '6' => '',
        '7' => '',
        '8' => 'Value4',
        '1' => '',
        '2' => 'Value5',
        '3' => '',
        '4' => '',
        '5' => [2, nil, nil, 8]
      }
    }
    multid_hash.list.size.should == 17
    multid_hash.list(flatten: Dog).size.should == 13
    multid_hash.list(flatten: [Dog, Array]).size.should == 10
    multid_hash.list(flatten: [Dog, Array], to_s: true).should == ['Value1', 'Value2', :cat, 'Value3', 'Struct::Dog', 'Object::Array', 'Struct::Dog', 'Value4', 'Value5', 'Object::Array']
    multid_hash.list(flatten: [Dog, Array], to_s: true)[4].class.should == String
    multid_hash.list(flatten: [Dog, Array])[4].class.should == Dog
    multid_hash.list(nil_or_empty: true).size.should == 41
    multid_hash.list(select: [Dog,Hash]).should == ["Value1", "Value2", :cat, "Value3", "Cocker Spaniel", "Brown", "Male", "Pitbull", "Albino", "Female", "Value4", "Value5"]
    multid_hash.list(select: Dog).should == []
    multid_hash.list(select: Hash).should == ["Value1", "Value2", :cat, "Value3", "Value4", "Value5"]
    multid_hash.list(ignore: Dog).should == ["Value1", "Value2", :cat, "Value3", 1, :bird, 3, "Value4", "Value5", 2, 8]
    multid_hash.list(ignore: [Dog, Array]).should == ["Value1", "Value2", :cat, "Value3", "Value4", "Value5"]
    multid_hash.list(ignore: Hash).should == []
  end
end
