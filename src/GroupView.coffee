define [
	'backbone'
	'underscore'
	'jquery'
	'GlobalChannel'
	'jquery.transit'
], (Backbone,_,$,GlobalChannel) ->


	Backbone.View.extend(

		className: 'articleGroup'

		tagName: 'li'

		template: null

		collection: null
		
		ItemView: Backbone.View.extend(
			
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

		initialize: ->

			@template = _.template $('#group-template').html()

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

				items = @collection.pluck 'itemView'
				_.each items, (view)->
					
					# get value in range between min and max

					numWords = view.model.get('numWords')
					top = wordsToTop(numWords)
					
					totalNumWords += numWords
				
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

				width = elementSize * items.length	
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

				top = wordsToTop totalNumWords/items.length
				@$('.average').css
					top: top  + topborder + bbox_border*2

			,@)

		events:

			'mouseover': -> @$('.boundingbox').addClass 'active'
			'mouseout': ->@$('.boundingbox').removeClass 'active'
			'click': -> 
				_.each @collection.pluck('itemView'), (view) -> view.$el.trigger 'click'

		render: (department,models)->

			if not @collection then @$el.html @template({department})

			$ul = @$('.articles')
			@collection = new Backbone.Collection(models)
			_.each @collection.where('itemView':null), (model)->

				itemView = new @ItemView( {model} ) 
				model.set('itemView',itemView)
				$ul.append itemView.$el

			,@
			@

	) 


	