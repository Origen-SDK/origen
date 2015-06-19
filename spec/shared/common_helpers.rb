shared_examples_for "a register" do
  it { reg.should respond_to(:size) }
end
