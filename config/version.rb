module Origen
  MAJOR = 0
  MINOR = 42
  BUGFIX = 2
  DEV = nil

  VERSION = [MAJOR, MINOR, BUGFIX].join(".") + (DEV ? ".pre#{DEV}" : '')
end
