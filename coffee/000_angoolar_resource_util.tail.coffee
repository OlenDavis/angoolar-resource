angoolar.escapeColons = ( text ) ->
	text?.
		replace( /:/g, '\\:' )