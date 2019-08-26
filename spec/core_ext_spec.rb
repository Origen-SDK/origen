require "spec_helper"

describe 'Ruby Core Extension Specs' do
  context "with 'default' target" do
    before(:each) { load_target('default') }

    describe Object do
      describe '#origen_subblock?' do
        it 'returns true if the given object inherits from either Origen::Model or Origen::Controller' do
          expect(dut.nvm.origen_subblock?).to be(true)
        end
        
        it 'returns false if the given object does not inherit from either Origen::Model or Origen::Controller' do
          expect(5.origen_subblock?).to be(false)
          expect('hello'.origen_subblock?).to be(false)
          expect(Origen.origen_subblock?).to be(false)
          expect(Origen.app.origen_subblock?).to be(false)
          expect(dut.nvm.class.origen_subblock?).to be(false)
        end
      end
    end
  end
end
