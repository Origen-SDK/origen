module <%= RGen.app.namespace %>
  MAJOR = <%= @version.major %>
  MINOR = <%= @version.minor %>
  BUGFIX = <%= @version.bugfix %>
  DEV = <%= @version.pre || "nil" %>

  VERSION = [MAJOR, MINOR, BUGFIX].join(".") + (DEV ? ".pre#{DEV}" : '')
end
