module Origen
  MAJOR = 0
  MINOR = 6
  BUGFIX = 12
  DEV = nil

  VERSION = [MAJOR, MINOR, BUGFIX].join(".") + (DEV ? ".pre#{DEV}" : '')
end
