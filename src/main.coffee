

# require libraries

jQuery = $ = require('jquery')
require('jquery.transit')
Backbone = require('backbone')
window._ = require('underscore')




#
#  GLOBAL CHANNEL
#


GlobalChannel = _.extend({},Backbone.Events)

# set up iframe browser / bind to headline click event

GlobalChannel.bind('headlineClicked windowResized', (headline) ->
	
	$wrapper = $('#mainWrapper')
	$selected = $('.selected_articles')
	$iframe = $('#iframeBrowser iframe')

	if headline
		
		headline.$el.toggleClass 'active'
				
		if headline.$el.is('.active') 
		
			# load headline article in iframe browser

			src = 'http://beta.nzz.ch/'+headline.model.get('guid')
			$iframe.attr({src})
			$selected.find('> li').removeClass('active')
			headline.$el.addClass('active')
	
	# set up wrapper and iframe

	doOpen = $selected.is(':has(.active)')

	win_height = $(window).height()
	topOffset = $selected.offset().top - $wrapper.offset().top
	headerHeight = win_height - topOffset
	iframeHeight = win_height - headerHeight
	top = if doOpen then - iframeHeight + 15 else 0
	$wrapper.css {top} 
	$iframe.height(iframeHeight).addClass 'active'

)

# bind to window resize event

GlobalChannel.bind('windowResized',->

	win_height = $(window).height()
	$selected = $('.selected_articles')
	$selected.height win_height - $selected.offset().top

)


#
#  SYNC API
#


Backbone.sync = (method, model, opts) ->

	return if method isnt 'read'

	url = if opts.useSampleData then './data_sample.html' else 'http://play.diary.ch/proxy/nzz.php'
	console.log url
	
	$('#throbber').removeClass 'inactive'
	$.ajax 
		type: 'GET'
		url: url
		data:
			limit: opts.limit or 100
			offset: opts.offset or 0
		success: (data) -> 

			self = @
			json = JSON.parse data
			success = -> opts.success.call model, _.values(json)

			$throbber = $('#throbber')
			$fountain = $throbber.find('#fountainG')
			$msg = $throbber.find('.msg')
			$btn = $throbber.find('.btn_go').not('.clicked')

			if $btn.length > 0

				$fountain.hide()
				$btn.addClass('active').click ->
					$(@).removeClass('active').addClass('clicked')
					$throbber.addClass 'inactive'
					$msg.html '<h1>Datenset wird erweitert.</h1>'
					$fountain.show()
					success.call(self)
			else
				$fountain.show()
				$throbber.addClass 'inactive'
				success.call(self)


#
#  ARTICLE MODEL
#


Article = Backbone.Model.extend(

	initialize: ->

		console.log 'init'
		json = @toJSON()
		
		# set main department

		@set('mainDepartment',if json.departmentNames then json.departmentNames[0] else 'none')

		# set length related attributes

		text = $(json.body).text()
		numWords = text.split(' ').length or 0
		wordsPerMin = 300
		time = Math.round(numWords/wordsPerMin*60)
		mins = Math.ceil(time / 60)
		# secs = time - mins * 60
		@set('numWords', numWords)
		@set('readLength', mins )
		@set('readTimeSecs', time )

)


#
#  COLLECTION
#


ArticleCollection = Backbone.Collection.extend(
	
	model: Article

	numDepArticles: 0
	totalReadTime: 0

	minWords: Number.MAX_VALUE
	maxWords: Number.MIN_VALUE

	excludedDepartments: ['News-Ticker','none']

	fetchStepLimit: 100
	currFetchStep: 0

	initialize: (@options)->
		
		@bind 'add', @updateWordCount, @

	updateWordCount: (model) ->

		if _.indexOf(@excludedDepartments,model.get('mainDepartment')) >= 0
			return @remove(model)

		numWords = model.get('numWords')
		@minWords = Math.min @minWords, numWords
		@maxWords = Math.max @maxWords, numWords	

	loadModels: (opts = {})->
		
		coll = @
		
		opts.limit ?= @fetchStepLimit
		opts.offset ?= @currFetchStep * @fetchStepLimit

		@fetch( 
			reset: opts.reset or false
			silent: false
			useSampleData: @options.useSampleData or false
			limit: opts.limit
			offset: opts.offset
			remove: false
			success: (coll,resp)->
				coll.currFetchStep += 1
		)

	getDepartmentArray: ->

		@numDepArticles = 0
		groups = @groupBy('mainDepartment')
		departmentArr = _.map groups, (models,department)->
			
			numArticles = models.length
			@numDepArticles += numArticles
			{department, models, numArticles}
		,@
		departments = _.sortBy departmentArr, 'numArticles'
		_.compact(departments).reverse()

	getTotalReadTime: ->

		totalTime = 0
		@each (model) -> totalTime += model.get('readTimeSecs')
		Math.round totalTime/60

	comparator: (model)-> return - new Date(model.get('updatedAt')).getTime()

)


#
#  CONTAINER VIEW
#


ItemContainerView = Backbone.View.extend(

	el: '#articleContainer'

	collection:null
	selection:null

	minWords:0
	maxWords:2500

	Headline: Backbone.View.extend(

		tagName:'li'
		className: 'btn headline'
		events:
			'mouseover': -> GlobalChannel.trigger('showToolbox',@model.get 'item-view')
			'mouseout': -> GlobalChannel.trigger('hideToolbox')
			'click': -> GlobalChannel.trigger('headlineClicked', @)
		render: ->
			@$el.append('<span>'+@model.get('title')+'</span>')
			@

	)

	initialize: (opts) ->

		# set up and load collection
		
		@collection = new ArticleCollection({}, opts)
		@collection.bind('sync', (opts)->
			@render()
		,@)
		@collection.loadModels(offset:0,reset:true)
		
		# set up empty selection

		@selection = new ArticleCollection()
		@selection.comparator = 'select-id'
		GlobalChannel.bind('articleToggled', (view)->
			@updateSelection(view)
		,@)

		# prepare texts

		$('.y_axis .setting .options .values').text( @minWords+' - '+@maxWords )

	events:

		'click': (e) -> 

			GlobalChannel.trigger 'hideToolbox'

		'click .y_axis .switch': (e) -> 
			
			$options = @$('.y_axis .options li').removeClass('active')
			$switch = @$('.y_axis .switch').toggleClass('down')
			if $switch.is('.down')
				$options.last().addClass('active')
				@render @collection.minWords,@collection.maxWords,false
			else
				$options.first().addClass('active')
				@render @minWords,@maxWords,false

		'click .load_more.btn': (e) -> @collection.loadModels(reset:false)

		'click .reload.btn': (e) -> @collection.loadModels(offset:0,reset:false)
		
		'click .read.btn': (e) -> GlobalChannel.trigger('headlineClicked', @selection.at(0).get('hl-view'))

	updateSelection: (view)->
		
		# remove from or add new article to selection

		{model} = view
		existing = @selection.findWhere id:model.get('id')
		if existing
			@selection.remove existing
		else 
			model.set 'select-id', @selection.length
			model.set 'item-view', view
			@selection.add model

		$panel = @$('.selection_panel')
		$readBtn = $panel.find('.read.btn').removeClass('inactive')
		$readTime = $panel.find('.readtime').removeClass('inactive')
		if @selection.length is 0 
			$readBtn.add($readTime).addClass 'inactive'

		readTime = @selection.getTotalReadTime()
		timeRatio = Math.round( readTime / @collection.getTotalReadTime() * 100 )
		$bar = $panel.find('.bar .filled').css width:timeRatio+'%'
		$readTime.find('.minutes').text( readTime )	
		$panel.find('.articles .num').text(@selection.length)

		# render selection

		$cont = @$('.selected_articles').empty()
		@selection.each (model)->
			hl = new @Headline({model})
			model.set 'hl-view', hl
			$cont.append hl.render().$el
		,@

	render: (min = @minWords, max = @maxWords, isInitial=true) ->

		# render group views

		departmentArr = @collection.getDepartmentArray()

		if isInitial
			$ul = @$('.groups').empty()
			_.each departmentArr, ( department )->
				{department,models} = department
				groupView = new GroupView()
				$ul.append groupView.$el
				groupView.render(department,models).$el
			,@	

		# notify about complete render

		v_space = 1
		bbox_border = 5
		width = @$('.groups').width()
		numArticles = @collection.numDepArticles
		size = Math.floor (width - (2*bbox_border+v_space)* departmentArr.length ) / numArticles
		
		GlobalChannel.trigger('doneRendering',
			elementSize:size
			bbox_border: bbox_border
			v_space: v_space
			min:min
			max:max
			range: max-min
			$yAxis: @$('.y_axis')  
			isInitial: isInitial
		)	

)


#
#  GROUP VIEW
#


GroupView = Backbone.View.extend(

	className: 'articleGroup'

	tagName: 'li'

	template: null

	items:null

	initialize: ->

		@template = _.template $('#group-template').html()
		@items = []

		GlobalChannel.bind('doneRendering',(params)->
			
			{elementSize,min,max,bbox_border,v_space,$yAxis,range,isInitial} = params
			border = 20
			topborder = @$('h2').height() + border/2
			height = @$el.height() - (topborder  + border/2)
			bbox_pos = top:height, bottom:0
			$yAxis.css height:height

			totalNumWords = 0

			wordsToTop = (numWords)->

				valInRange = Math.min( range, Math.max(0,numWords-min) ) 
				ratio = valInRange/range
				Math.round ratio * height 

			_.each @items, (view)->
				
				# get value in range between min and max

				numWords = view.model.get('numWords')
				totalNumWords += numWords
				top = wordsToTop(numWords)
			
				view.$el.css
					width: elementSize
					height: elementSize
					left: elementSize * view.$el.index() + bbox_border

				if isInitial 
					view.$el.css top: Math.round(1 * height) + topborder + bbox_border

				view.$el.transit
					delay: Math.random()*100
					easing:'snap'
					top: top + topborder + bbox_border
				, Math.random()*500 + 500 	

				bbox_pos.top = Math.min top, bbox_pos.top
				bbox_pos.bottom = Math.max top + elementSize, bbox_pos.bottom

			# set bounding box' size

			width = elementSize * @items.length	
			@$el.css width: width + bbox_border*2 + v_space	
			@$('.boundingbox').css 
				width: width + bbox_border*2
				height: bbox_pos.bottom - bbox_pos.top + bbox_border*2
				top: bbox_pos.top + topborder
				opacity:0
			.transit
				delay:1000
				opacity:1
			, 300 + @$el.index() * 200

			# set average line's top

			top = wordsToTop totalNumWords/@items.length
			@$('.average').css
				top: top  + topborder + bbox_border*2

		,@)

	events:

		'mouseover': -> @$('.boundingbox').addClass 'active'
		'mouseout': -> 
			@$('.boundingbox').removeClass 'active'
			# GlobalChannel.trigger('hideToolbox')

		'click': -> 
			_.each @items, (item) -> item.$el.trigger 'click'


	render: (department,models)->

		@$el.html @template {department}
		$ul = @$('.articles')
		_.each models, (model)->
			itemView = new ItemView( {model} ) 
			$ul.append itemView.$el
			@items.push itemView
		,@
		@

) 


#
#  ITEM VIEW
#


ItemView = Backbone.View.extend(
	
	className: 'articleItem'
	
	tagName: 'li'

	events:

		'click': (e)-> 

			e.stopPropagation()
			@$el.toggleClass 'active'
			GlobalChannel.trigger('articleToggled',@)
			
		'mouseover': (e) -> GlobalChannel.trigger('showToolbox',@)			
		
		'mouseout': (e) -> GlobalChannel.trigger('hideToolbox',@)
	
)


#
#  TOOL-TIP BOX
#


TooltipBox = Backbone.View.extend(

	el: '#articleTooltipbox'

	currArticle:null

	template: null

	initialize: ->

		@template = _.template $('#tooltip-template').html()
		
		GlobalChannel.bind('showToolbox', (article)->
			
			article.$el.addClass 'hovered'
			if @currArticle and @currArticle isnt article then @currArticle.$el.removeClass 'hovered'
			@render(article)

		,@)

		GlobalChannel.bind('hideToolbox', ()->
			
			if @$el.is('.visible') # and not @$el.is('.hovered') 
				if @currArticle then @currArticle.$el.removeClass 'hovered'
				@$el.removeClass('visible').addClass('hidden')

		,@)
	
	render: (article) ->

		@$el.removeClass('move')
		if not @$el.is('.visible') then @$el.removeClass('hidden').addClass('visible')
		else
			@$el.addClass('move')

		{left,top} = article.$el.offset()
		@$el.css
			top: top + 30
			left: left - @$el.width()/2
		json = article.model.toJSON()
		@$el.html @template json
		@currArticle = article
)


#
#  INITIALIZE ASSOCIATED VIEWS (el prop)
#


$(document).ready -> 
	
	new ItemContainerView(useSampleData:no)
	new TooltipBox()

	GlobalChannel.trigger('windowResized')

