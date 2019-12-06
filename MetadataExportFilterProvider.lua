--[[----------------------------------------------------------------------------

ExportFilterProvider.lua

Defines the dialog section to be displayed in the Export dialog and provides the
filter process before the photos are exported.

------------------------------------------------------------------------------]]

local LrView = import 'LrView'
local bind = LrView.bind
local LrTasks = import 'LrTasks'
local LrFileUtils = import 'LrFileUtils'

--------------------------------------------------------------------------------
-- We specify any presets here

local exportPresetFields = {
    { key = 'HierarchicalKeywords', default = true },
    { key = 'LensAsKeyword', default = true },
    { key = 'AddPeopleTags', default = true },
}

--------------------------------------------------------------------------------

local function setError( propertyTable, message )
    propertyTable.message = message
    propertyTable.hasError = true
    propertyTable.hasNoError = false
    propertyTable.LR_canExport = false
end

--------------------------------------------------------------------------------

local function clearError( propertyTable )
    propertyTable.message = nil
    propertyTable.hasError = false
    propertyTable.hasNoError = true
    propertyTable.LR_canExport = true
end

--------------------------------------------------------------------------------
-- This function will check the status of the Export Dialog to determine 
-- if all required fields have been populated.

local function updateFilterStatus( propertyTable, ... )
    --[[
    if propertyTable.metachoice == nil then
    setError( propertyTable, LOC "$$$/SDK/MetaExportFilter/Messages/choice=Please choose which type of metadata to filter" )
    elseif propertyTable.metavalue == nil then
    setError( propertyTable, LOC "$$$/SDK/MetaExportFilter/Messages/choice=Please enter the required matching string" )
    else
    clearError( propertyTable )
    end
    --]]
end

--------------------------------------------------------------------------------
-- This optional function adds the observers for our required fields metachoice and metavalue so we can change
-- the dialog depending on whether they have been populated.

local function startDialog( propertyTable )

    --propertyTable:addObserver( 'metachoice', updateFilterStatus )
    --propertyTable:addObserver( 'metavalue', updateFilterStatus )
    updateFilterStatus( propertyTable )

end

--------------------------------------------------------------------------------
-- This function will create the section displayed on the export dialog 
-- when this filter is added to the export session.

local function sectionForFilterInDialog( view, propertyTable )
	
    return {
        title = LOC "$$$/MetadataExportFilterProvider/SectionTitle=Alex's Metadata Post Process",
		
        view:row {
            view:checkbox {
                title = LOC "$$$/MetadataExportFilterProvider/HierarchicalKeywords=Set keywords to Windows compatable hierarchical keywords",
                value = bind 'HierarchicalKeywords'
            }
        },

        view:row {
            view:checkbox {
                title = LOC "$$$/MetadataExportFilterProvider/LensAsKeyword=Add lens information as a keyword",
                value = bind 'LensAsKeyword'
            }
        },

        view:row {
            view:checkbox {
                title = LOC "$$$/MetadataExportFilterProvider/AddPeopleTags=Add keywords under the People hierarchy as a person tag",
                value = bind 'AddPeopleTags'
            }
        },
    }
end

--------------------------------------------------------------------------------

local function getMetadata( photo )

    -- reference: http://www.robcole.com/Lightroom/SDK%203.0/API%20Reference/modules/LrPhoto.html

    local rawProps = { 
        "rating", "shutterSpeed", "aperture", "exposureBias", "flash",
        "isoSpeedRating", "focalLength", "focalLength35mm", "gpsAltitude", 
        "colorNameForLabel", "dateTimeISO8601", "dateTimeOriginalISO8601",
        "dateTimeDigitizedISO8601" }
				
        local formattedProps = { 
            "keywordTags", "keywordTagsForExport",
            "title", "caption", "exposureProgram", "meteringMode", "lens", 
            "subjectDistance", "cameraMake", "cameraModel", "cameraSerialNumber",
            "artist", "software", "creator", "creatorJobTitle", "creatorAddress", 
            "creatorCity", "creatorStateProvince", "creatorPostalCode", 
            "creatorCountry", "creatorPhone", "creatorEmail", "creatorUrl", 
            "headline", "iptcSubjectCode", "descriptionWriter", "iptcCategory", 
            "iptcOtherCategories", "intellectualGenre", "scene", "location", 
            "city", "stateProvince", "country", "isoCountryCode", "jobIdentifier", 
            "instructions", "provider", "source", "copyright", "rightsUsageTerms", 
            "copyrightInfoUrl", "personShown", "nameOfOrgShown", "codeOfOrgShown", 
            "event", "additionalModelInfo", "modelAge", "minorModelAge", 
            "modelReleaseStatus", "modelReleaseID", "sourceType", "propertyReleaseID", 
            "propertyReleaseStatus", "digImageGUID", "plusVersion" }

            local metadata = {}

            for i,prop in ipairs(rawProps) do
                local val = photo:getRawMetadata(prop)
                if val then
                    metadata[prop] = val
                end
            end

            for i,prop in ipairs(formattedProps) do
                local val = photo:getFormattedMetadata(prop)
                if val then
                    metadata[prop] = val
                end
            end

            local gps = photo:getRawMetadata('gps')
            if gps then
                metadata.gps = gps.latitude .. ',' .. gps.longitude
            end

            local keywords = photo:getRawMetadata('keywords')
            if keywords then
                local hierarchies = ''
                for i,keyword in ipairs(keywords) do
                    local name = keyword:getName()
                    keyword = keyword:getParent()
                    while keyword do
                        name = keyword:getName() .. '|' .. name
                        keyword = keyword:getParent()
                    end
                    hierarchies = hierarchies .. name .. ';'
                end

                metadata.hierarchicalSubject = hierarchies
            end

            -- TODO: locationCreated: (table) The location where the photo was taken. Each element in the return table is a table which is a structure named LocationDetails as defined in the IPTC Extension spec. Definition details can be found at http://www.iptc.org/std/photometadata/2008/specification/. 
            -- TODO: locationShown: (table) The location shown in this image. Each element in the return table is a table which is a structure named LocationDetails as defined in the IPTC Extension spec. Definition details can be found at http://www.iptc.org/std/photometadata/2008/specification/. 
            -- TODO: artworksShown: (table) A set of metadata about artwork or an object in the image. Each element in the return table is a table which is a structure named ArtworkOrObjectDetails as defined in the IPTC Extension spec. Definition details can be found at http://www.iptc.org/std/photometadata/2008/specification/. 
            -- TODO: imageSupplier: (table) Identifies the most recent supplier of this image, who is not necessarily its owner or creator. Each element in the return table is a table which is a structure named ImageSupplierDetail defined in PLUS. Definition details can be found at http://ns.useplus.org/LDF/ldf-XMPReference. 
            -- TODO: registryId: (table) Both a Registry Item Id and a Registry Organization Id to record any registration of this photo with a registry. Each element in the return table is a table which is a structure named RegistryEntryDetail as defined in the IPTC Extension spec. Definition details can be found at http://www.iptc.org/std/photometadata/2008/specification/. 
            -- TODO: imageCreator: (table) Creator or creators of the image. Each element in the return table is a table which is a structure named ImageCreatorDetail defined in PLUS. Definition details can be found at http://ns.useplus.org/LDF/ldf-XMPReference. 
            -- TODO: copyrightOwner: (table) Owner or owners of the copyright in the licensed image. Each element in the return table is a table which is a structure named CopyrightOwnerDetail defined in PLUS. Definition details can be found at http://ns.useplus.org/LDF/ldf-XMPReference. 
            -- TODO: licensor: (table) A person or company that should be contacted to obtain a license for using the photo, or who has licensed the photo. Each element in the return table is a table which is a structure named LicensorDetail defined in PLUS. Definition details can be found at http://ns.useplus.org/LDF/ldf-XMPReference. 
            return metadata
        end

        --------------------------------------------------------------------------------

        local function postProcessRenderedPhotos( functionContext, filterContext )

            local renditionOptions = {
                filterSettings = function( renditionToSatisfy, exportSettings )
                    exportSettings.LR_minimizeEmbeddedMetadata = false
                    exportSettings.LR_metadata_keywordOptions = 'lightroomHierarchical'
                end,
            }

            for sourceRendition, renditionToSatisfy in filterContext:renditions( renditionOptions ) do
                -- Wait for the upstream task to finish its work on this photo.
                local success, pathOrMessage = sourceRendition:waitForRender()
                if success then
                    local photo = sourceRendition.photo
                    local metadata = getMetadata(photo)
                    local metadataPath = pathOrMessage .. ".metadata"

                    LrFileUtils.delete(metadataPath)
                    local f = io.open(metadataPath, "w")
                    for k,v in pairs(metadata) do
                        f:write(k .. "=" .. tostring(v) .. "\n")
                    end
                    f:close()
            
                    if MAC_ENV then sep = '/' else sep = '\\' end

                    local cmd = 'perl'
                    cmd = cmd .. ' "-I' .. _PLUGIN.path .. sep .. 'lib"'
                    cmd = cmd .. ' "' .. _PLUGIN.path .. sep .. 'postProcessRenderedPhotos.pl"'
                    cmd = cmd .. ' "-metadata=' .. metadataPath .. '"'
                    cmd = cmd .. ' "-source='   .. photo:getRawMetadata('path') .. '"'
                    cmd = cmd .. ' "-target='   .. pathOrMessage .. '"'

                    local status = LrTasks.execute( cmd )
                    if status ~= 0 then
                        renditionToSatisfy:renditionIsDone( false, "Alex's Metadata Post Process failure: " .. status .. " " .. cmd )
                    end

                    --LrFileUtils.delete(metadataPath)
            
                    --[[
                    -- Lightroom props: http://www.robcole.com/Lightroom/SDK%203.0/API%20Reference/modules/LrPhoto.html
                    -- Propsys keys: http://msdn.microsoft.com/en-us/library/windows/desktop/dd561977(v=vs.85).aspx
                    local pscall = _PLUGIN.path .. '\\pscall.exe "' .. pathOrMessage .. '"'
                    local lens = photo:getFormattedMetadata("lens")
                    if lens then
                    pscall = pscall .. ' "-System.Photo.LensModel=' .. lens .. '"'
                    end
                    pscall = pscall .. ' "-System.Photo.CameraSerialNumber=' .. photo:getFormattedMetadata("cameraSerialNumber") .. '"'
                    pscall = pscall .. ' -System.DateModified:=System.Photo.DateTaken'		
                    -- if video rating -> System.Rating
                    -- if video datetimeiso8601/datetimedigitizediso8601/datetimeoriginaliso8601 -> System.DateModified, System.Document.DateCreated, System.Document.DateSaved, System.ItemDate, System.Media.DateEncoded
                    -- if video gps -> System.GPS.Latitude, System.GPS.Longitude
                    local pscallStatus = LrTasks.execute( pscall )
                    --]]
                end
            end
        end

        --------------------------------------------------------------------------------

        return {
            exportPresetFields = exportPresetFields,
            startDialog = startDialog,
            sectionForFilterInDialog = sectionForFilterInDialog,
            postProcessRenderedPhotos = postProcessRenderedPhotos,
        }
