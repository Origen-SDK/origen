module Origen
  MAJOR = 0
  MINOR = 26
  BUGFIX = 0
  DEV = nil

  VERSION = [MAJOR, MINOR, BUGFIX].join(".") + (DEV ? ".pre#{DEV}" : '')
end
