module Origen
  MAJOR = 0
  MINOR = 54
  BUGFIX = 1
  DEV = nil
  VERSION = [MAJOR, MINOR, BUGFIX].join(".") + (DEV ? ".pre#{DEV}" : '')
end
