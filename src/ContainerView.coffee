define [
	'backbone'
	'underscore'
	'jquery'
	'ArticleCollection'
	'GroupView'
	'GlobalChannel'
], (Backbone,_,$,ArticleCollection,GroupView,GlobalChannel) ->


	Backbone.View.extend(

		el: '#articleContainer'

		collection:null
		selection:null

		minWords:0
		maxWords:2500

		Headline: Backbone.View.extend(

			tagName:'li'
			className: 'btn headline'
			events:
				'mouseover': -> GlobalChannel.trigger('showToolbox',@model.get 'itemView')
				'mouseout': -> GlobalChannel.trigger('hideToolbox')
				'click': -> GlobalChannel.trigger('headlineClicked', @)
			render: ->
				@$el.append('<span>'+@model.get('title')+'</span>')
				@

		)

		initialize: (opts) ->

			# set up and load collection
			
			@collection = new ArticleCollection(opts)
			@collection.bind('sync', (collection,models,opts)->
				@render @minWords, @maxWords, opts.reset
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
					@render @collection.minWords, @collection.maxWords
				else
					$options.first().addClass('active')
					@render @minWords, @maxWords

			'click .load_more.btn': (e) -> @collection.loadModels(reset:false)

			'click .reload.btn': (e) -> @collection.loadModels(offset:0,reset:true)
			
			'click .read.btn': (e) -> GlobalChannel.trigger('headlineClicked', @selection.at(0).get('hl-view'))

		updateSelection: (view)->
			
			# remove from or add new article to selection

			{model} = view
			existing = @selection.findWhere id:model.get('id')
			if existing
				@selection.remove existing
			else 
				model.set 'select-id', @selection.length
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

			@renderSelection()
			

		renderSelection: ->

			$cont = @$('.selected_articles').empty()
			@selection.each (model)->
				hl = new @Headline({model})
				model.set 'hl-view', hl
				$cont.append hl.render().$el
			,@

		render: (min, max, isReset = false) ->

			# render group views

			$ul = @$('.groups')			
			departmentArr = @collection.getDepartmentArray()
			
			if isReset 
				$ul.empty()
				@selection.reset()
				@renderSelection()

			@collection.departments.each ( model )->

				{department,models} = _.findWhere departmentArr,{department:model.get('name')}
				groupView = model.get('groupView')
				if isReset or not groupView

					groupView = new GroupView()
					model.set('groupView',groupView)
					$ul.append groupView.$el
				
				groupView.render(department,models).$el
			,@	

			# notify about complete render

			v_space = 1
			bbox_border = 2
			numArticles = @collection.length
			numDepartments = @collection.departments.length
			widthRange = @$('.groups').width() - (2*bbox_border+v_space)*numDepartments - v_space
			size = Math.floor widthRange / numArticles
			
			GlobalChannel.trigger('doneRendering',
				elementSize:size
				bbox_border: bbox_border
				v_space: v_space
				min:min
				max:max
				range: max-min
				$yAxis: @$('.y_axis')  
				isInitial: isReset
			)	

	)
