define [
	'backbone'
	'underscore'
	'jquery'
], (Backbone,_,$) ->
	
	Backbone.Collection.extend(

		model: Backbone.Model.extend(

			defaults:
				
				itemView: null

			initialize: ->

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

		totalReadTime: 0

		minWords: Number.MAX_VALUE
		maxWords: Number.MIN_VALUE

		departments: null
		excludedDepartments: ['News-Ticker','none']

		fetchStepLimit: 100
		currFetchStep: 0

		initialize: (@options)->
			
			@departments = new Backbone.Collection
			@departments.comparator = (model)-> return -model.get('numArticles')
			@bind 'add', @update, @

		update: (model) ->

			department = model.get('mainDepartment')
			if _.indexOf(@excludedDepartments,department) >= 0
				return @remove(model)

			existing = @departments.findWhere(name:department)	
			if not existing
				@departments.add new Backbone.Model(name:department, numArticles:1, groupView:null)
			else
				existing.set 'numArticles', existing.get('numArticles') + 1

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

			groups = @groupBy('mainDepartment')
			departmentArr = _.map groups, (models,department)->
				
				numArticles = models.length
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
