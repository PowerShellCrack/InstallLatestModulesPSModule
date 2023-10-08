# Change log for InstallLatestModule module

## 1.0.5 October 8, 2023

- Fixed exported cmdlets
- Added Compare-LatestModule Alias to support older module
- Both cmdlets returns objects
- removed excessive output and changed to verbose messages

## 1.0.4 February 2, 2023

- Fixed Name for pileline calls; added alias ModuleName
- Remove command to set trusted repository. This should be done elsewhere

## 1.0.2 February 2, 2023

- Removed un-needed files
- Added Compare-LatestModule cmdlet

## 1.0.1 February 2, 2023

- Removed frequency check; unneeded for module
- Fixed ouyput to create new line during pipeline calls
- Changed loging to transcript install of dependency on logging module (YetAnotherCMLogger)

## 1.0.0 January 23, 2023

- Initial build

