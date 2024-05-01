module Origen
  MAJOR = 0
  MINOR = 60
  BUGFIX = 14
  DEV = nil
  VERSION = [MAJOR, MINOR, BUGFIX].join(".") + (DEV ? ".pre#{DEV}" : '')
end
