module Origen
  MAJOR = 0
  MINOR = 7
  BUGFIX = 31
  DEV = nil

  VERSION = [MAJOR, MINOR, BUGFIX].join(".") + (DEV ? ".pre#{DEV}" : '')
end
