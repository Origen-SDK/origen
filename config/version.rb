module Origen
  MAJOR = 0
  MINOR = 64
  BUGFIX = 1
  DEV = nil
  VERSION = [MAJOR, MINOR, BUGFIX].join(".") + (DEV ? ".pre#{DEV}" : '')
end
