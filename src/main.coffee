
jQuery = $ = require('jquery')
Backbone = require('backbone')
window._ = require('underscore')


links = []
departments = []

Article = Backbone.Model.extend(

	initialize: ->

		json = @toJSON()
		
		# collection images

		images = []
		leadImage = json.leadImage
		mediaReferences = json['media-references']
		if leadImage then images.push leadImage
		if mediaReferences then images = images.concat _.values mediaReferences.image
		
		img_urls = []
		if images.length > 0
			for img in images
				img_urls.push(img.originalUrl)
		@set('images', img_urls)
		@set('mainDepartment',json.departmentNames[0])

		# collect text_volume

		textVolume = $(json.body).text().length
		console.log textVolume
		@set('text_volume', textVolume)
		@set('sentences', $(json.body).text().split('.').length)

		# collect global variables

		$(json.body).find('a[href]').each ->
			links.push $(@).attr('href')

		if json.departmentNames
			for name in json.departmentNames
				if not departments[name] then departments[name] = 1
				else departments[name]++


)

ArticleCollection = Backbone.Collection.extend(
	
	model: Article

	comparator: (model)-> return - new Date(model.get('updatedAt')).getTime()


)


#
#  CONTAINER VIEW
#

ItemContainerView = Backbone.View.extend(

	el: '#articleList'

	collection:null

	subviews:null

	initialize: ->

		@subviews = []
		view = @
		$.ajax 
			type: 'GET'
			url: 'http://play.diary.ch/proxy/nzz.php'
			data:
				limit: 50
				offset:0
			success: (data)->
				json = JSON.parse data
				view.collection = new ArticleCollection( _.values json )
				view.render()

	render: () ->
		
		groups = @collection.groupBy('mainDepartment')
		delete groups['News-Ticker']
		console.log groups

		_.each groups, (models,department )->
			console.log department
			_.each models, (model)->
				console.log model
				itemView = new ItemView( {model} ) 
				@$el.append itemView.render().$el
				@subviews.push itemView
			,@
		,@	
		console.log links
		console.log departments
)


#
#  ITEM VIEW
#


ItemView = Backbone.View.extend(
	
	className: 'articleItem'
	
	tagName: 'li'

	template: null

	initialize: ->
		
		@template = _.template $('#item-template').html()

	events:

		'click': -> @$el.toggleClass 'active'
		'click a': (e) -> e.stopPropagation()


	render: ->
		json = @model.toJSON()
		# console.log json
		if json.isBreakingNews then @$el.addClass 'breaking'
		if json.departmentNames and json.departmentNames[0] is 'News-Ticker' then @$el.addClass 'newsticker'
		@$el.html @template json
		@
)


#
#  KICK OFF
#


$(document).ready -> new ItemContainerView()



		


