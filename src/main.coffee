

# 
# LIBRARY DEPENDENCIES
#


jQuery = $ = require('jquery')
Backbone = require('backbone')
window._ = require('underscore')


#
# VIEW DEPENDENCIES
#


ContainerView = require('ContainerView')
TooltipBox = require('TooltipView')


#
#  GLOBAL CHANNEL
#


GlobalChannel = require('GlobalChannel')

# set up iframe browser / bind to headline click event

GlobalChannel.bind('headlineClicked windowResized', (headline) ->
	
	$wrapper = $('#mainWrapper')
	$selected = $('.selected_articles')
	$iframe = $('#iframeBrowser iframe')

	# if activated, load headline article in iframe browser

	if headline and headline.$el.toggleClass('active').is('.active') 
		
		$iframe.attr(src:'http://beta.nzz.ch/'+headline.model.get('guid'))
		$selected.children().not(headline.$el).removeClass('active')
	
	# set up wrapper and iframe

	doOpen = $selected.is(':has(.active)')
	win_height = $(window).height()
	topOffset = $selected.offset().top - $wrapper.offset().top
	headerHeight = win_height - topOffset
	iframeHeight = win_height - headerHeight
	$wrapper.css top: if doOpen then - iframeHeight + 15 else 0
	$iframe.height(iframeHeight).addClass 'active'

)

# bind to window resize event

GlobalChannel.bind('windowResized',->

	win_height = $(window).height()
	$selected = $('.selected_articles')
	$selected.height win_height - $selected.offset().top

)


#
#  CUSTOM BACKBONE SYNC
#


Backbone.sync = (method, model, opts) ->

	return if method isnt 'read'

	url = if opts.useSampleData then './data_sample.html' else 'http://play.diary.ch/proxy/nzz.php'
	console.log 'loading ' + url
	
	# show throbber while loading

	$throbber = $('#throbber').removeClass('hidden').addClass('visible')
	$fountain = $throbber.find('#fountainG')
	hideThrobber = (data)->
		$throbber.removeClass('visible').addClass('hidden')
		$fountain.show()
		json = JSON.parse data 
		opts.success.call model, _.values(json)
	
	# show loading message

	$msg = $throbber.find('.msg')
	$btn = $throbber.find('.btn_go').not('.clicked')	
	isBtnUnclicked = $btn.length > 0
	className = switch
		when isBtnUnclicked then 'intro' 
		when opts.offset is 0 then 'reload' 
		else 'load_more'
	$msg.children().addClass('inactive').filter('.'+className).removeClass('inactive')
	
	# load via ajax

	$.ajax
		type: 'GET'		
		url: url		
		data: limit: opts.limit or 100, offset: opts.offset or 0
		success: (data) -> 
			
			self = @
			
			if isBtnUnclicked
				$fountain.hide()
				$btn.addClass('active').click ->
					$(@).removeClass('active').addClass('clicked')
					hideThrobber.call(self,data)
			else				
				hideThrobber.call(self,data)


#
#  INITIALIZATION OF NON-GENERIC VIEWS
#


$(document).ready -> 
	
	new ContainerView(useSampleData:no)
	new TooltipBox()

	GlobalChannel.trigger('windowResized')

