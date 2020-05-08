module Origen
  MAJOR = 0
  MINOR = 55
  BUGFIX = 5
  DEV = nil
  VERSION = [MAJOR, MINOR, BUGFIX].join(".") + (DEV ? ".pre#{DEV}" : '')
end
