require "zlib"

class GzipFilter < Nanoc::Filter
  identifier :gzip

  type text: :binary

  def run(content, params = {})
    Zlib::GzipWriter.open(output_filename, Zlib::BEST_COMPRESSION) do |gz|
      gz.orig_name = "index.html"
      gz.mtime = File.mtime(item[:filename]).to_i
      gz.write content
    end
  end

end
