RSpec.shared_examples :utility_collector_spec do
  
  describe 'Collector' do
    it 'can be initialized with an empty to_h' do
      collector = Origen::Utility::Collector.new
      expect(collector).to be_a(Origen::Utility::Collector)
      expect(collector.to_h).to eql({})
    end
    
    it 'implements ::to_h and aliases it to ::to_hash' do
      collector = Origen::Utility::Collector.new
      expect(collector).to respond_to(:to_h)
      expect(collector.method(:to_h)).to eql(collector.method(:to_hash))
    end
    
    it 'has a shortcut method Origen::Utility.collector' do
      collector = Origen::Utility.collector
      expect(collector).to be_a(Origen::Utility::Collector)
      expect(collector.to_h).to eql({})
    end
    
    it 'collects given method/argument pairs from a block and returns them as a hash' do
      block = Proc.new do |collector|
        collector.arg1 'hi'
        collector.arg2 'hello'
        collector.arg3 'hi'
        collector.arg4 'hello'
      end
      collector = Origen::Utility.collector(&block).to_h
      expect(collector).to eql({arg1: 'hi', arg2: 'hello', arg3: 'hi', arg4: 'hello'})
    end
    
    it 'collects given method/argument pairs using either \'arg val\' or \'arg= val\' format' do
      block = Proc.new do |collector|
        collector.arg1 = 'hi'
        collector.arg2 'hello'
        collector.arg3 'hi'
        collector.arg4 = 'hello'
      end
      collector = Origen::Utility.collector(&block).to_h
      expect(collector).to eql({arg1: 'hi', arg2: 'hello', arg3: 'hi', arg4: 'hello'})
    end
    
    it 'collects given method/argument and method/block pairs and returns them as a hash' do
      block = Proc.new do |collector|
        collector.arg1 'hi'
        collector.arg2 do
          'nothing'
        end
        collector.arg3 do
          'also nothing'
        end
      end
      collector = Origen::Utility.collector(&block).to_h
      expect(collector.keys).to eql([:arg1, :arg2, :arg3])
      expect(collector[:arg1]).to eql('hi')
      expect(collector[:arg2]).to be_a(Proc)
      expect(collector[:arg3]).to be_a(Proc)
      expect(collector[:arg2].call).to eql('nothing')
      expect(collector[:arg3].call).to eql('also nothing')
    end
    
    describe 'Auto-Merging' do
      it 'can auto-merge with a given options hash, preserving the original options' do
        options = {argA: 'arg A', argB: 'arg B'}
        block = Proc.new do |collector|
          collector.arg1 'arg 1'
          collector.arg2 'arg 2'
        end
        collector = Origen::Utility.collector(hash: options, &block).to_h
        expect(collector).to eql({argA: 'arg A', argB: 'arg B', arg1: 'arg 1', arg2: 'arg 2'})
        expect(options).to eql({argA: 'arg A', argB: 'arg B'})
      end
      
      it 'allows auto-merging methodology to be queried' do
        collector = Origen::Utility.collector
        expect(collector).to respond_to(:merge_method)
      end
      
      it 'has a default auto-merge setting to :keep_hash' do
        collector = Origen::Utility.collector
        expect(collector.merge_method).to eql(:keep_hash)
      end
      
      it 'allows auto-merging methodology to be set as an option' do
        collector = Origen::Utility.collector(merge_method: :keep_block)
        expect(collector.merge_method).to eql(:keep_block)
      end
      
      it 'complains if an unknown auto-merging methodology is given' do
        expect {
          Origen::Utility.collector(merge_method: :unknown)
        }.to raise_error(Origen::OrigenError, 'Origen::Utility::Collector cannot merge with method :unknown (of class Symbol). Known merge methods are :keep_hash (default), :keep_block, or :fail')
      end
      
      it 'merges the options with merging: :keep_hash' do
        options = {arg1: 'has arg 1', arg2: 'hash arg 2'}
        block = Proc.new do |collector|
          collector.arg2 'block arg 2'
          collector.arg3 'block arg 3'
        end
        collector = Origen::Utility.collector(hash: options, merge_method: :keep_hash, &block).to_h
        expect(collector).to eql({arg1: 'has arg 1', arg2: 'hash arg 2', arg3: 'block arg 3'})
      end
      
      it 'merges the options with merging: :keep_block' do
        options = {arg1: 'has arg 1', arg2: 'hash arg 2'}
        block = Proc.new do |collector|
          collector.arg2 'block arg 2'
          collector.arg3 'block arg 3'
        end
        collector = Origen::Utility.collector(hash: options, merge_method: :keep_block, &block).to_h
        expect(collector).to eql({arg1: 'has arg 1', arg2: 'block arg 2', arg3: 'block arg 3'})
      end
      
      it 'merges the options with merging: :fail' do
        options = {arg1: 'has arg 1', arg2: 'hash arg 2'}
        block = Proc.new do |collector|
          collector.arg2 'block arg 2'
          collector.arg3 'block arg 3'
        end
        expect {
          Origen::Utility.collector(hash: options, merge_method: :fail, &block)
        }.to raise_error(Origen::OrigenError, 'Origen::Utility::Collector detected both the hash and block attempting to set :arg2 (merge_method set to :fail)')
      end
    end
    
    describe 'Fail Conditions' do      
      it 'complains if an option method was already set (resets not allowed)' do
        block = Proc.new do |collector|
          collector.arg1 'hi'
          collector.arg1 = 'hello'
        end
        expect {
          Origen::Utility.collector(&block)
        }.to raise_error(Origen::OrigenError, 'Origen::Utility::Collector does not allow method :arg1 to be set more than a single time. :arg1 is set to hi, tried to set it again to hello')
      end
      
      it 'complains if no arguments are given (sets fail on empty args)' do
        block = Proc.new do |collector|
          collector.arg1
        end
        Origen.log.deprecate "This test should be edited for Origen 1.0.0 release"
        expect {
          Origen::Utility.collector(fail_on_empty_args: true, &block)
        }.to raise_error(ArgumentError, 'Origen::Utility::Collector does not allow method :arg1 to have no arguments. A single argument must be provided')
      end
      
      it 'complains if more than one argument is given' do
        block = Proc.new do |collector|
          collector.arg1 'arg1', 'arg2', 'arg3'
        end
        expect { 
          Origen::Utility.collector(&block)
        }.to raise_error(ArgumentError, 'Origen::Utility::Collector does not allow method :arg1 more than 1 argument. Received 3 arguments.')
      end
      
      it 'complains if an argument list and block are both given' do
        block = Proc.new do |collector|
          collector.arg1('arg1') do
            'nothing'
          end
        end
        expect {
          Origen::Utility.collector(&block)
        }.to raise_error(ArgumentError, 'Origen::Utility::Collector cannot accept both an argument list and block simultaneously for :arg1. Please use one or the other.')
      end
    end
    
  end
end
