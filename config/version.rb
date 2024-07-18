module Origen
  MAJOR = 0
  MINOR = 60
<<<<<<< Updated upstream
  BUGFIX = 15
=======
  BUGFIX = 16
>>>>>>> Stashed changes
  DEV = nil
  VERSION = [MAJOR, MINOR, BUGFIX].join(".") + (DEV ? ".pre#{DEV}" : '')
end
