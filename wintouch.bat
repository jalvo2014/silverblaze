@SetLocal EnableDelayedExpansion
@set FILE=%1
@type nul >>%FILE::=_%.touch & copy %FILE::=_%.touch +,, >nul 2>&1
@EndLocal
