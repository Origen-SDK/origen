require 'yaml'
class Regexp
  def to_txt(options = {})
    options = {
      no_mods: false
    }.update(options)
    expr, mods = '', ''
    if to_yaml.match(/regexp\s+\/(.*)\/(.*)/).nil?
      Origen.log.error('Cannot convert the regular expression to text, something changed in the YAML view of the regular expressions')
      fail
    else
      (expr, mods) = to_yaml.match(/regexp\s+\/(.*)\/(.*)/).captures
    end
    options[:no_mods] ? "\/#{expr}\/" : "\/#{expr}\/#{mods}"
  end
end
