module Origen
  MAJOR = 0
  MINOR = 7
  BUGFIX = 38
  DEV = 1

  VERSION = [MAJOR, MINOR, BUGFIX].join(".") + (DEV ? ".pre#{DEV}" : '')
end
