require 'spec_helper'

describe 'session stores' do

  before :each do
    Origen.app.session.spec
  end
  
  describe 'it can create a store and add keys' do
    Origen.app.session.spec[:first_key] = 1
    Origen.app.session.spec[:first_key].should == 1
    Origen.app.session.has_key?(:spec).should == true
    Origen.app.session.spec.has_key?(:first_key).should == true
  end
  
  describe 'it can delete a key' do
    Origen.app.session.spec.delete_key(:first_key)
    Origen.app.session.spec.has_key?(:first_key).should == false
  end
  
  describe 'it can return its keys as an array' do
    Origen.app.session.spec[:first_key] = 1
    Origen.app.session.spec[:second_key] = 2
    Origen.app.session.spec.keys.sort.should == [:first_key, :second_key]
  end
 
end
