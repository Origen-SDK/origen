module Origen
  MAJOR = 0
  MINOR = 59
  BUGFIX = 4
  DEV = nil
  VERSION = [MAJOR, MINOR, BUGFIX].join(".") + (DEV ? ".pre#{DEV}" : '')
end
