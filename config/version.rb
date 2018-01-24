module Origen
  MAJOR = 0
  MINOR = 30
  BUGFIX = 0
  DEV = nil

  VERSION = [MAJOR, MINOR, BUGFIX].join(".") + (DEV ? ".pre#{DEV}" : '')
end
