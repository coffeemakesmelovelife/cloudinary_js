
toAttribute = (key, value) ->
  if !value
    undefined
  else if value == true
    key
  else
    "#{key}=\"#{value}\""

###*
* combine key and value from the `attr` to generate an HTML tag attributes string.
* `Transformation::toHtmlTagOptions` is used to filter out transformation and configuration keys.
* @param {Object} attr
* @return {String} the attributes in the format `'key1="value1" key2="value2"'`
###
html_attrs = (attrs) ->
  pairs = _.map(attrs, (value, key) -> toAttribute( key, value))
  pairs.sort()
  pairs.filter((pair) ->
                 pair
              ).join ' '

###*
* Represents an HTML (DOM) tag
*
* Usage: tag = new HtmlTag( 'div', { 'width': 10})
###
class HtmlTag

  constructor: (name, public_id, options)->
    @name = name
    @public_id = public_id
    if !options?
      if _.isPlainObject(public_id)
        options = public_id
        @public_id = undefined
      else
        options = {}
    @options = _.cloneDeep(options)
    transformation = new Transformation(options)
    transformation.setParent(this)
    @transformation = ()->
      transformation

  ###*
  * Convenience constructor
  ###
  @new = (name, public_id, options)->
    new @(name, public_id, options)

  # REVIEW options and transformation will become out of sync. consider having one dynamically retrieved from the other.
  getOptions: ()-> @options

  attributes: ()->
    @transformation().toHtmlAttributes()

  setAttr: ( name, value)->
    @transformation().set( name, value)
    this

  getAttr: (name)->
    @attributes()[name]

  removeAttr: (name)->
    delete @attributes()[name]

  content: ()->
    ""

  openTag: ()->
    "<#{@name} #{html_attrs(@attributes())}>"

  closeTag:()->
    "</#{@name}>"

  content: ()->
    ""

  toHtml: ()->
    @openTag() + @content()+ @closeTag()

###*
* Creates an HTML (DOM) Image tag using Cloudinary as the source.
###
class ImageTag extends HtmlTag

  ###*
  * Creates an HTML (DOM) Image tag using Cloudinary as the source.
  * @param {String} public_id
  * @param {Object} [options]
  ###
  constructor: (@public_id, options={})->
    super("img", @public_id, options)

  closeTag: ()->
    ""

  attributes: ()->
    attr = super() || []
    attr['src'] ?= new Cloudinary(@options).url( @public_id)
    attr

###*
* Creates an HTML (DOM) Video tag using Cloudinary as the source.
###
class VideoTag extends HtmlTag

  VIDEO_TAG_PARAMS = ['source_types','source_transformation','fallback_content', 'poster']
  DEFAULT_VIDEO_SOURCE_TYPES = ['webm', 'mp4', 'ogv']
  DEFAULT_POSTER_OPTIONS = { format: 'jpg', resource_type: 'video' }

  ###*
  * Defaults values for parameters.
  *
  * (Previously defined using option_consume() )
  ###
  DEFAULT_VIDEO_PARAMS ={
    fallback_content: ''
    resource_type: "video"
    source_transformation: {}
    source_types: DEFAULT_VIDEO_SOURCE_TYPES
    transformation: []
    type: 'upload'
  }

  ###*
  * Creates an HTML (DOM) Video tag using Cloudinary as the source.
  * @param {String} public_id
  * @param {Object} [options]
  ###
  constructor: (publicId, options={})->
    options = _.defaults(_.cloneDeep(options), DEFAULT_VIDEO_PARAMS)

    super("video", publicId.replace(/\.(mp4|ogv|webm)$/, ''), options)

#    @whitelist.push("source_transformation", "source_types", "poster")
#    @fromOptions(options)

  setSourceTransformation: (value)->
    @sourceTransformation = value
    this

  setSourceTypes: (value)->
    @sourceType = value
    this

  setPoster: (value)-> @poster = value

  content: ()->
    sourceTypes = @options['source_types']
    sourceTransformation = @options['source_transformation']
    fallback = @options['fallback_content']

    if _.isArray(sourceTypes)
      innerTags = for source_type in sourceTypes
        transformation = sourceTransformation[source_type] or {}
        src = new Cloudinary(@options).url( "#{@public_id }",
                    _.defaults({ resource_type: 'video', format: source_type},
                               transformation,
                               @options))
        videoType = if source_type == 'ogv' then 'ogg' else source_type
        mimeType = 'video/' + videoType
        '<source ' + html_attrs(
          src: src
          type: mimeType) + '>'
    else
      innerTags = []
    innerTags.join('') + fallback

  attributes: ()->
    sourceTypes = @options['source_types']
    poster = @options['poster']

    if poster?
      if _.isPlainObject(poster)
        if poster.public_id?
          poster = new Cloudinary(@options).url( "#{poster.public_id }", poster)
        else
          poster = new Cloudinary(@options).url( this, @public_id, _.defaults( @options.poster, DEFAULT_POSTER_OPTIONS))
    else
      poster = new Cloudinary(@options).url(@public_id, _.defaults( @options, DEFAULT_POSTER_OPTIONS))

    attr = super() || []
    attr = _.omit(attr, VIDEO_TAG_PARAMS)
    unless  _.isArray(sourceTypes)
      attr["src"] = new Cloudinary(@options).url("#{@public_id}",
                                                 _.defaults({ resource_type: 'video', format: sourceTypes},
                                                            @options))
    if poster?
      attr["poster"] = poster
    attr

# unless running on server side, export to the windows object
unless module?.exports? || exports?
  exports = window

exports.Cloudinary ?= {}
exports.Cloudinary.HtmlTag = HtmlTag
exports.Cloudinary.ImageTag = ImageTag
exports.Cloudinary.VideoTag = VideoTag
