class OrigenGlobalApplication < Origen::Application
  config.output_directory do
    "#{Origen.root}/origen"
  end

  config.reference_directory do
    "#{Origen.root}/origen/.ref"
  end
end
