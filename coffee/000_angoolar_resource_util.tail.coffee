# This takes a name like 'SomethingCrazy' and turns it into 'something_crazy'
angoolar.camelToUnderscores = ( someText ) -> 
	someText?.
		replace( /([a-z])([A-Z])/g, ( match, lowerPart, upperPart ) -> lowerPart + '_' + upperPart.toLowerCase() ).
		toLowerCase()

# This takes a name like 'SomethingCrazy' and turns it into 'something-crazy'
angoolar.camelToDashes = ( someText ) -> 
	someText?.
		replace( /([a-z])([A-Z])/g, ( match, lowerPart, upperPart ) -> lowerPart + '-' + upperPart.toLowerCase() ).
		toLowerCase()

angoolar.escapeColons = ( text ) ->
	text?.
		replace( /:/g, '\\:' )