module Origen
  MAJOR = 0
  MINOR = 60
  BUGFIX = 11
  DEV = nil
  VERSION = [MAJOR, MINOR, BUGFIX].join(".") + (DEV ? ".pre#{DEV}" : '')
end
