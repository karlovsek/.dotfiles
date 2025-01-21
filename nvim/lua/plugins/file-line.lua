-- Plugin for vim to enable opening a file in a given line
-- When you open a file:line, for instance when coping and pasting from an error from your compiler vim tries to open a file with a colon in its name.
--
-- Examples:
--
-- vim index.html:20
-- vim app/models/user.rb:1337
return {
  { "bogado/file-line" },
}
