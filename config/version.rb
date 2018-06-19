module Origen
  MAJOR = 0
  MINOR = 33
  BUGFIX = 2
  DEV = nil

  VERSION = [MAJOR, MINOR, BUGFIX].join(".") + (DEV ? ".pre#{DEV}" : '')
end
