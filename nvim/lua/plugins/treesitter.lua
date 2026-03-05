-- Empty override to document that nvim-treesitter parser downloads
-- require the curl and tar wrappers in ~/.local/bin/ which:
--   curl: rewrites github.com/archive/{sha}.tar.gz -> codeload.github.com
--   tar:  adds --touch to suppress "Cannot utime" in container environments
-- Both are installed by install-minimal.sh.
return {}
