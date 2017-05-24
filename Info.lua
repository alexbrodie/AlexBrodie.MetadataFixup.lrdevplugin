--[[----------------------------------------------------------------------------

Info.lua

For exported files:
* Converts LR keyword hierarchy (full one including individual non-exported keywords in the hierarchy) to Windows compatable one for use in Explorer and Windows [Live] Photo Gallery
* Adds lens information as a keyword so that it is easily searchable in Explorer and Windows [Live] Photo Gallery
* Adds any keywords under the People| hierarchy as a person tag
* Adds metadata to exported mp4's:
- rating 
- keywords
- date taken
- gps

Windows 7 (Vista may work, but it's untested) and Perl installation with ExifTool (ActivePerl recommended) required

------------------------------------------------------------------------------]]

return {

    LrSdkVersion = 4.0,
    LrSdkMinimumVersion = 4.0, -- minimum SDK version required by this plugin

    LrPluginName = LOC "$$$/Name=Alex's Metadata Post Process",
    LrToolkitIdentifier = 'alexbrodie.metadatafixup',

    LrExportServiceProvider = {
        title = LOC "$$$/ExportServiceProvider=Alex's Export", -- the string that appears in the export location menu
        file = "ExportServiceProvider.lua",
    },
	
    LrExportFilterProvider = {
        title = LOC "$$$/MetadataExportFilterProvider=Alex's Metadata Post Process", -- the string that appears in the export filter section of the export dialog in LR
        file = 'MetadataExportFilterProvider.lua', -- name of the file containing the filter definition script
        id = "alexbrodie.metadatafixup",  -- unique identifier for export filter
        supportsVideo = "true",
    },

    VERSION = { major=1, minor=0, revision=0, build=0, },

}
