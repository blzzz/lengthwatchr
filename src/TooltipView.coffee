define [
	'backbone'
	'underscore'
	'jquery'
	'GlobalChannel'
], (Backbone,_,$,GlobalChannel) ->
	
	Backbone.View.extend(

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

			# @$el.removeClass('move')
			if not @$el.is('.visible') then @$el.removeClass('hidden').addClass('visible')
			# else
			# 	@$el.addClass('move')

			{left,top} = article.$el.offset()
			@$el.css
				top: top + 30
				left: left - @$el.width()/2
			json = article.model.toJSON()
			@$el.html @template json
			@currArticle = article
	)