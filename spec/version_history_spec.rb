require "spec_helper"

describe "Version History Class" do
  it 'Initialize without label and external_changes_internal' do
    new_ver_hist = Origen::Specs::Version_History.new('10-31-2016', 'John Doe', 'Change 1')
    new_ver_hist.date.should == '10-31-2016'
    new_ver_hist.author.should == 'John Doe'
    new_ver_hist.changes.should == 'Change 1'
    new_ver_hist.label.should == nil
    new_ver_hist.external_changes_internal == nil
  end
  it 'Initialize with label and without external_changes_internal' do
    new_ver_hist = Origen::Specs::Version_History.new('11-1-2016', 'Jane Doe', 'Change 2', 'label.01.02.03.04')
    new_ver_hist.date.should == '11-1-2016'
    new_ver_hist.author.should == 'Jane Doe'
    new_ver_hist.changes.should == 'Change 2'
    new_ver_hist.label.should == 'label.01.02.03.04'
    new_ver_hist.external_changes_internal == nil    
  end
  it 'Initialize with label and external_changes_internal' do
    new_ver_hist = Origen::Specs::Version_History.new('11-1-2016', 'Jane Doe', 'Change 2', 'label.01.02.03.04', false)
    new_ver_hist.date.should == '11-1-2016'
    new_ver_hist.author.should == 'Jane Doe'
    new_ver_hist.changes.should == 'Change 2'
    new_ver_hist.label.should == 'label.01.02.03.04'
    new_ver_hist.external_changes_internal == false        
  end
  it 'Changes is a Hash' do
    change_hash = {
      internal:  'Internal Changes',
      external:  'External Changes'
    }
    new_ver_hist = Origen::Specs::Version_History.new('11-1-2016', 'Jane Doe', change_hash, 'label.01.02.03.04', false)
    new_ver_hist.date.should == '11-1-2016'
    new_ver_hist.author.should == 'Jane Doe'
    new_ver_hist.changes.should == change_hash
    new_ver_hist.label.should == 'label.01.02.03.04'
    new_ver_hist.external_changes_internal == false            
  end
end