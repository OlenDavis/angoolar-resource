
angoolar.BaseResource = class BaseResource extends angoolar.Named
	$_prefix: '' # by default, we don't want to prefix our resource names
	$_makeName: ->
		try
			name = angoolar.camelToDashes super # dasherize the name of the resource
		catch e
			name = ''

		name

	$_idProperty: null # If defined, automatically appends the specified property underscored as the last path segment of the API path made for this resource (e.g. /:id), and adds the given property to $_properties as '=@'

	$_makeApiPath: ->
		apiPath = "/#{ @$_makeName() }"
		apiPath += "/:#{ @$_makeApiProperty @$_idProperty }" if @$_idProperty?.length

		apiPath

	$_underscoreProperties: no

	$_makeApiProperty : ( property ) -> if @$_underscoreProperties then angoolar.camelToUnderscores property else property
	$_makeJsonProperty: ( property ) -> if @$_underscoreProperties then angoolar.camelToUnderscores property else property

	# This object's keys correspond to this object's properties/members, and its values correspond to the corresponding
	# keys in any JSON object being parsed from or to this object.
	# $_propertyToJsonMapping: {}
	# 	property: 'corresponding_json_property'
	# 	etc     : 'corresponding_json_etc'
	$_propertyToJsonMapping: {}

	# This object's keys correspond to this object's properties/members, and its values correspond to the corresponding
	# API parameters in the $_apiPath of any class extending BaseRequester class that lists this class extending
	# BaseResource. For instance for a BaseRequester::$_apiPath of "something/:correspondingApiParameter/etc/:apiEtc"
	# the following would be a valid $_propertyToApiMapping:
	# $_propertyToApiMapping: {}
	# 	property: 'correspondingApiParameter'
	# 	etc     : 'apiEtc'
	$_propertyToApiMapping: {}

	# This allows for a completely consistent treatment of all properties and how they are serialized/deserialized. To include
	# a property to be serialized/deserialized, simply include its field name in this object as a key, with a value of one of:
	#	*	'='                           - the property will be serialized into and deserialized from JSON
	#	*	'@'                           - the property will be used as a parameter for all requests
	#	*	'=@'                          - both = and @
	#	*	function extends BaseResource - the property will be serialized into and deserialized from JSON as an instance of the
	#		                                given resource
	#	*	'=@BaseResourceOnAngoolar'    - a function extending BaseResource with that name will be found on angoolar and used
	#                                       to serialize the corresponding JSON and/or API property.
	$_properties: {}

	# This allows us to have properties of the resource be instances of other resources. The following is an example using
	# all possible parameters on each resource property. The key of each property of $_propertyToResourceJsonMapping is the property
	# of this resource that will be populated with an instance or an array of instances of the resource class given by each
	# each corresponding resourceClass, which must be a class extending BaseResource.
	#
	# (If the jsonExpression refers to a property that's an array, it will loop through each object in the array and add an
	# instance of the given resourceClass for each.)
	# $_propertyToResourceJsonMapping:
	# 	assets: # our property name
	# 		assets: # the json property name
	# 			angoolar.Asset # the BaseResource-extending class used to make an instance for each (if an array) object in the json property
	#		weirdAssets:
	#			angoolar.WeirdAsset
	$_propertyToResourceJsonMapping: {}
	$_propertyToResourceApiMapping : {}
	# As an aside for future development, I would like to see this work with the $_propertyToApiMapping member to actually 
	# allow the propertyToApiMapping object contain all the property references, but this to determine whether those references
	# are simple (or just what their JSON representations are) or class instances, given by this member. And maybe that would
	# be better suited by a different member that ecompasses both declarations in one BaseResource property.

	# By setting this to yes, then the JSON expressions can use `this` and have it refer to the JSON object itself.
	# You should set this to `no` if you know that your JSON responses will have a field called `this` as it would
	# be overriden by the self reference if `$_useThis` is `yes`.
	$_useThis: yes

	constructor: ->
		unless @constructor::hasOwnProperty( '$_propertiesConfigured' ) and @constructor::$_propertiesConfigured
			@constructor::$parse = angular.injector( [ 'ng' ] ).get "$parse"

			@constructor::$_properties                    = angoolar.prototypallyExtendPropertyObject @, '$_properties'
			@constructor::$_propertyToJsonMapping         = angoolar.prototypallyExtendPropertyObject @, '$_propertyToJsonMapping'
			@constructor::$_propertyToApiMapping          = angoolar.prototypallyExtendPropertyObject @, '$_propertyToApiMapping'
			@constructor::$_propertyToResourceJsonMapping = angoolar.prototypallyExtendPropertyObject @, '$_propertyToResourceJsonMapping'
			@constructor::$_propertyToResourceApiMapping  = angoolar.prototypallyExtendPropertyObject @, '$_propertyToResourceApiMapping'
			@constructor::$_allProperties                 = _.union(
				_.keys @constructor::$_properties
				_.keys @constructor::$_propertyToJsonMapping
				_.keys @constructor::$_propertyToApiMapping
				_.keys @constructor::$_propertyToResourceJsonMapping
				_.keys @constructor::$_propertyToResourceApiMapping
			)

			if @$_idProperty?.length and not @$_properties[ @$_idProperty ]?
				@constructor::$_properties[ @$_idProperty ] = '=@'

			for property, propertyUsage of @$_properties
				jsonProperty = @$_makeJsonProperty property
				apiProperty  = @$_makeApiProperty property

				if angular.isString propertyUsage
					if /[@=]{1,2}/.test propertyUsage
						inJson = -1 isnt propertyUsage.indexOf '='
						inApi  = -1 isnt propertyUsage.indexOf '@'

						@constructor::$_propertyToJsonMapping[ property ] = jsonProperty if inJson
						@constructor::$_propertyToApiMapping[  property ] = apiProperty  if inApi
					else
						usageMatches = propertyUsage.match /([@=]{0,2})([^@=]+)/
						usage             = usageMatches[ 1 ]
						resourceClassName = usageMatches[ 2 ]

						usage = '=' unless usage?.length

						inJson = -1 isnt usage.indexOf '='
						inApi  = -1 isnt usage.indexOf '@'

						if angular.isFunction angoolar[ resourceClassName ]
							( resourceJsonMapping = {} )[ jsonProperty ] = angoolar[ resourceClassName ]
							( resourceApiMapping  = {} )[ apiProperty  ] = angoolar[ resourceClassName ]

							@constructor::$_propertyToResourceJsonMapping[ property ] = resourceJsonMapping if inJson
							@constructor::$_propertyToResourceApiMapping[  property ] = resourceApiMapping  if inApi

				else if angular.isFunction propertyUsage
					resourceMapping = {}
					resourceMapping[ jsonProperty ] = propertyUsage

					@constructor::$_propertyToResourceJsonMapping[ property ] = resourceMapping

			@constructor::$_propertiesConfigured = yes

		@$_init()

	# Copies all requestable properties not excluded in excludeProperties to this resource from anotherResource
	copy: ( anotherResource, excludeProperties = {} ) =>
		for field in @$_allProperties
			unless excludeProperties[ field ]
				@[ field ] = angular.copy anotherResource[ field ]

	# This method is used to initialize the resource after it's been created - i.e. including the constructor and JSON deserialization
	$_init: ->

	# If there's a resource requester extending BaseRequester that declares this class as its $_resourceClass, then for each of the non-GET
	# actions it declares, there can be two corresponding methods on each instance of this class returned by its various actions according to the
	# following rule:
	# For successful post-processing of the action: $actionSuccess( resourceResponse, headersGetter ) ->
	# For erroneous post-processing of the action: $actionError( resourceResponse, headersGetter ) ->

	$_toJson: ->
		json = {}

		json.this = json if @$_useThis

		# Actually assign all the JSON properties properly to the resource if possible
		angular.forEach @$_propertyToJsonMapping, ( jsonExpression, propertyExpression ) =>
			propertyExpressionGetter = @$parse propertyExpression
			jsonExpressionSetter = @$parse( jsonExpression ).assign
			jsonExpressionSetter json, propertyExpressionGetter @

		@$_putResourcesOnto json, @$_propertyToResourceJsonMapping

		angoolar.delete json, 'this' if @$_useThis

		json

	$_fromJson: ( json ) ->
		if json?
			json.this = json if @$_useThis # this is to allow expressions to use `this` to refer to the json object itself

			# Actually assign all the JSON properties properly to the resource if possible
			angular.forEach @$_propertyToJsonMapping, ( jsonExpression, propertyExpression ) =>
				jsonExpressionGetter = @$parse jsonExpression
				jsonValue = jsonExpressionGetter json

				propertyExpressionGetter = @$parse propertyExpression
				propertyExpressionSetter = propertyExpressionGetter.assign
				propertyExpressionSetter @, jsonValue

			@$_getResourcesFrom json, @$_propertyToResourceJsonMapping

			angoolar.delete json, 'this' if @$_useThis

		@$_init()

		@ # for method chaining

	$_putResourcesOnto: ( target, resourceMapping ) ->
		# Assign all the aggregated resources
		angular.forEach resourceMapping, ( aggregateResourceDefinition, propertyExpression ) =>
			propertyExpressionGetter = @$parse propertyExpression

			angular.forEach aggregateResourceDefinition, ( resourceClass, jsonExpression ) =>
				jsonExpressionSetter = @$parse( jsonExpression ).assign

				jsonAggregateResources = new Array()
				isPropertyArray = no

				aggregatedResourceObjectOrArray = propertyExpressionGetter @
				return unless angular.isDefined aggregatedResourceObjectOrArray

				if aggregatedResourceObjectOrArray instanceof resourceClass
				# If the property is an instance of the given resource
					jsonAggregateResources.push aggregatedResourceObjectOrArray.$_toJson()

				else if angular.isArray aggregatedResourceObjectOrArray
				# If the property is an array of instances of the given resource class
					isPropertyArray = yes

					for aggregatedResource in aggregatedResourceObjectOrArray
						jsonAggregateResources.push aggregatedResource.$_toJson() if aggregatedResource instanceof resourceClass

				else if angular.isObject( aggregatedResourceObjectOrArray )
				# If the property is actually a hash of the given resource
					isPropertyArray = yes

					for aggregatedResource of aggregatedResourceObjectOrArray
						jsonAggregateResources.push aggregatedResource.$_toJson() if aggregatedResource instanceof resourceClass

				if isPropertyArray or jsonAggregateResources.length > 1
					jsonExpressionSetter target, jsonAggregateResources
				else
					jsonExpressionSetter target, jsonAggregateResources[ 0 ]

	$_getResourcesFrom: ( target, resourceMapping ) ->
		# Assign all the aggregated resources
		angular.forEach resourceMapping, ( aggregateResourceDefinition, propertyExpression ) =>
			# We will first assume we're not going to be attributing these aggregated resources to the given propertyExpression evaluation as an array unless (1), any
			# of the aggregated resources (given by its corresponding jsonExpression) is an array, or (2), we have multiple aggregated resources
			# that each correspond to this same propertyExpression evaluation.
			isPropertyArray = no
			jsonResources = new Array()

			propertyExpressionGetter = @$parse propertyExpression
			propertyExpressionSetter = propertyExpressionGetter.assign

			angular.forEach aggregateResourceDefinition, ( resourceClass, jsonExpression ) =>
				jsonExpressionGetter = @$parse jsonExpression
				jsonResourceObjectOrArray = jsonExpressionGetter target

				if angular.isArray jsonResourceObjectOrArray
					isPropertyArray = isPropertyArray or yes
					for jsonResourceDatum in jsonResourceObjectOrArray
						jsonResources.push if jsonResourceDatum? then new resourceClass().$_fromJson( jsonResourceDatum ) else jsonResourceDatum
				else
					jsonResources.push if jsonResourceObjectOrArray? then new resourceClass().$_fromJson( jsonResourceObjectOrArray ) else jsonResourceObjectOrArray

			if isPropertyArray or jsonResources.length > 1
				propertyExpressionSetter @, jsonResources
			else
				propertyExpressionSetter @, jsonResources[ 0 ]

	$_getApiParameters: ->
		parameters = {}

		for property, apiParameter of @$_propertyToApiMapping
			parameters[ apiParameter ] = @[ property ] if @[ property ]?

		@$_putResourcesOnto parameters, @$_propertyToResourceApiMapping

		parameters

	$_setApiParameters: ( parameters ) ->
		for property, apiParameter of @$_propertyToApiMapping
			@[ property ] = parameters[ apiParameter ] if parameters?[ apiParameter ]?

		@$_getResourcesFrom parameters, @$_propertyToResourceApiMapping

		@ # for method chaining