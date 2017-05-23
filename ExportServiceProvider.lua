
local LrApplication = import 'LrApplication'
local LrDialogs = import 'LrDialogs'
local LrFileUtils = import 'LrFileUtils'
local LrTasks = import 'LrTasks'
local LrView = import 'LrView'
local bind = LrView.bind

return {
	exportPresetFields = { 
		{ key = 'BaseLocation', default = 'Initial value' },
	}, 
	
	hideSections = { 
		'exportLocation' 
	},

	startDialog = function( propertyTable ) 
	end, 
	
	endDialog = function( propertyTable, why )
	end, 
	
	sectionsForTopOfDialog = function( view, propertyTable )
		return {
			{
				title = LOC "$$$/ExportServiceProvider/SectionTitle=Location",

				view:row {
					view:static_text {
						title = LOC "$$$/ExportServiceProvider/LocationTitle=Parent directory:",
						fill_horizontal = 1,
					}
				},

				view:row {
					view:edit_field {
						value = bind 'BaseLocation',
						validate = LrFileUtils.exists,
						fill_horizontal = 1,
					},
					view:push_button {
						title = LOC "$$$/ExportServiceProvider/BrowseLocationButton=Browse...",
						action = function( button )
							local dirs = LrDialogs.runOpenPanel({
								prompt = LOC "$$$/ExportServiceProvider/SelectFolder=Select Folder",
								canChooseFiles = false,
								canChooseDirectories = true,
								allowsMultipleSelection = false,
							})

							if dirs then
								propertyTable.BaseLocation = dirs[1];
							end
						end
					}
				},

				view:row {
					view:static_text {
						title = LOC "$$$/ExportServiceProvider/ExampleTitle=Example:",
						fill_horizontal = 1,
					}
				},

				view:row {
					view:static_text {
						title = bind {
							key = 'BaseLocation',
							transform = function( value, fromTable )
								local catalog = LrApplication.activeCatalog()
								local photo = catalog:getTargetPhoto()
								if photo then
									local p = photo:getRawMetadata('path')
									return value .. 'd'
								else
									return value .. 'xyz'
								end
								--photo.catalog
								
							end
						},
						fill_horizontal = 1,
					}
				},
			},
		}
	end, 
	
	processRenderedPhotos = function( functionContext, exportContext ) 
	end
}
