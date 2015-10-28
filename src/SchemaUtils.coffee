global = @

# TODO(aramk) Move this to Objects utility.
# Adds support for using object arguments with _.memoize().
nextMemoizeObjKey = 1
memoizeObjectArg = (func) ->
  _.memoize func, (obj) ->
    key = obj._memoizeObjKey
    unless key?
      key = obj._memoizeObjKey = nextMemoizeObjKey++
    key

SchemaUtils =

  projectIdProperty: 'project'

  getParameterField: (paramId) -> Collections.getField(Entities, ParamUtils.addPrefix(paramId))

  # Traverse the given schema and call the given callback with the field schema and ID.
  forEachFieldSchema: (schema, callback) ->
    fieldIds = schema._schemaKeys
    for fieldId in fieldIds
      fieldSchema = schema.schema(fieldId)
      if fieldSchema?
        callback(fieldSchema, fieldId)

  getSchemaReferenceFields: (collection) ->
    refFields = {}
    schema = collection.simpleSchema()
    Collections.forEachFieldSchema schema, (field, fieldId) ->
      if field.collectionType
        refFields[fieldId] = field
    refFields

  getSchemaReferenceFieldsMemoized: (collection) ->
    _.memoize(SchemaUtils.getSchemaReferenceFields, Collections.getName.bind(Collections))(collection)

  getRefModifier: (model, collection, idMaps) ->
    modifier = {}
    $set = {}
    modifier.$set = $set
    refFields = @getSchemaReferenceFields(collection)
    _.each refFields, (field, fieldId) =>
      collectionName = Collections.getName(global[field.collectionType])
      # TODO(aramk) Refactor out logic for looking up fields in modifier format.
      oldId = Objects.getModifierProperty(model, fieldId)
      newId = idMaps?[collectionName]?[oldId]
      return unless oldId? && newId?
      $set[fieldId] = newId
    modifier

  getParameterValue: (obj, paramId) ->
    # Allow paramId to optionally contain the prefix.
    paramId = ParamUtils.removePrefix(paramId)
    # Allow obj to contain "parameters" map or be the map itself.
    target = obj[ParamUtils.prefix] ? obj ?= {}
    Objects.getModifierProperty(target, paramId)

  setParameterValue: (model, paramId, value) ->
    paramId = ParamUtils.removePrefix(paramId)
    target = model[ParamUtils.prefix] ?= {}
    Objects.setModifierProperty(target, paramId, value)

  # TODO(aramk) Move to objects util.
  unflattenParameters: (doc, hasParametersPrefix) ->
    Objects.unflattenProperties doc, (key) ->
      if !hasParametersPrefix || ParamUtils.hasParametersPrefix(key)
        key.split('.')
      else
        null

  getDefaultParameterValues: memoizeObjectArg (collection) ->
    values = {}
    schema = collection.simpleSchema()
    Collections.forEachFieldSchema schema, (fieldSchema, paramId) ->
      defaultValue = fieldSchema.defaultValue
      if defaultValue? then values[paramId] = defaultValue
    SchemaUtils.unflattenParameters(values, false)

  mergeDefaultParameterValues: (model, collection) ->
    defaults = @getDefaultParameterValues(collection)
    prefix = ParamUtils.prefix
    model[prefix] ?= {}
    Setter.defaults(model[prefix], defaults[prefix])
    model

  findByProject: (collection, projectId, args) ->
    if Types.isObjectLiteral(projectId)
      args = projectId
      projectId = null
    projectId ?= Projects.getCurrentId()
    defaultArgs = {}
    defaultArgs[@projectIdProperty] = projectId
    args = _.extend(defaultArgs, args)
    if projectId
      collection.find(args)
    else
      throw new Error('Project ID not provided - cannot retrieve models.')

  extendSchema: (orig, changes) -> _.extend({}, orig, changes)

  autoLabel: (field, id) ->
    label = field.label
    if label?
      label
    else
      label = id.replace('_', '')
      Strings.toTitleCase(label)

  getFieldLabel: (paramId) ->
    field = @getParameterField(paramId)
    field.label ? Strings.toTitleCaseFromCamel(_.last(paramId.split('.')))

  createCategorySchemaObj: (cat, catId, args) ->
    catSchemaFields = {}
    hasRequiredField = false
    _.each cat.items, (item, itemId) =>
      if item.items?
        result = @createCategorySchemaObj(item, itemId, args)
        if result.hasRequiredField
          hasRequiredField = true
        fieldSchema = result.schema
      else
        # Required fields must explicitly specify "optional" as false.
        fieldSchema = _.extend({optional: true}, args.itemDefaults, item)
        if fieldSchema.optional == false
          hasRequiredField = true
        @autoLabel(fieldSchema, itemId)
      catSchemaFields[itemId] = fieldSchema
    catSchema = new SimpleSchema(catSchemaFields)
    catSchemaArgs = _.extend({
      # If a single field is required, the entire category is marked required. If no fields are
      # required, the category can be omitted.
      optional: !hasRequiredField
    }, args.categoryDefaults, cat, {type: catSchema})
    @autoLabel(catSchemaArgs, catId)
    delete catSchemaArgs.items
    {hasRequiredField: hasRequiredField, schema: catSchemaArgs}

  # Constructs SimpleSchema fields which contains all categories and each category is it's own
  # SimpleSchema.
  createCategoriesSchemaFields: (args) ->
    args ?= {}
    cats = args.categories
    unless cats
      throw new Error('No categories provided.')
    # For each category in the schema.
    catsFields = {}
    for catId, cat of cats
      result = @createCategorySchemaObj(cat, catId, args)
      catsFields[catId] = result.schema
    catsFields

  createCategoriesSchema: (args) -> new SimpleSchema(@createCategoriesSchemaFields(args))

  forEachCategoryField: (category, callback) ->
    for itemId, item of category.items
      if item.items?
        @forEachCategoryField(item, callback)
      else
        callback(itemId, item, category)

  forEachCategoriesField: (categories, callback) ->
    for catId, category of categories
      @forEachCategoryField(category, callback)

  mergeObjectsWithTemplate: (args) ->
    template = args.template
    result = {}
    _.map args.items, (item, itemId) ->
      result[itemId] = Setter.merge(Setter.clone(template), item)
    result

  mergeDefaultsWithTemplate: (args) ->
    items = args.items
    _.each items, (value, key) ->
      items[key] = {defaultValue: value}
    @mergeObjectsWithTemplate(args)

  ################################################################################################
  # COMMON SCHEMA DEFINITION
  ################################################################################################

  nameSchema: ->
    type: String
    index: true
    unique: false

  descSchema: ->
    label: 'Description'
    type: String
    optional: true

  projectSchema: ->
    label: 'Project'
    type: String
    index: true
    collectionType: 'Projects'

  heightSchema: ->
    type: Number
    decimal: true
    desc: 'Maximum height of the entity (excluding elevation).'
    units: 'm'

  elevationSchema: ->
    type: Number
    decimal: true
    desc: 'Elevation from ground-level to the base of this entity.'
    units: 'm'

  calcArea: (id) ->
    feature = AtlasManager.getEntity(id)
    if feature
      target = feature.getForm('footprint')
      unless target
        target = feature.getForm('mesh')
      unless target
        throw new Error('GeoEntity was found but no footprint or mesh exists - cannot ' +
          'calculate area.')
      target.getArea()
    else
      throw new Error('GeoEntity not found - cannot calculate area.')

  calcLength: (id) ->
    feature = AtlasManager.getEntity(id)
    line = feature.getForm('line')
    unless line
      throw new Error('Cannot calculate length of non-line GeoEntity with ID ' + id)
    line.getLength()

  areaSchema: ->
    label: 'Area'
    type: Number
    desc: 'Area of the land parcel.'
    decimal: true
    units: 'm^2'
    calc: -> @calcArea(@model._id)

####################################################################################################
# SCHEMA OPTIONS
####################################################################################################

# SimpleSchema.debug = true
SimpleSchema.extendOptions
  # Optional extra fields.
  desc: Match.Optional(String)
  units: Match.Optional(String)
  # Used on reference fields containing IDs of models in the given collection type.
  collectionType: Match.Optional(String)
  # An expression for calculating the value of the given field for the given model. These are output
  # fields and do not appear in forms. The formula can be a string containing other field IDs
  # prefixed with '$' (e.g. $occupants) which are resolved to the local value per model, or global
  # parameters if no local equivalent is found. If the expression is a function, it is passed the
  # current model and the field and should return the result.
  calc: Match.Optional(Match.Any)
