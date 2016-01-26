module Origen
  MAJOR = 0
  MINOR = 5
  BUGFIX = 9
  DEV = nil

  VERSION = [MAJOR, MINOR, BUGFIX].join(".") + (DEV ? ".pre#{DEV}" : '')
end
