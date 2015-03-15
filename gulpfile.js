var gulp = require('gulp');
var coffee = require('gulp-coffee');
var connect = require('gulp-connect');
var stylus = require('gulp-stylus');
var nib = require('nib');
var webpack = require('gulp-webpack');
var webpackModule = require('webpack');
var watch = require('gulp-watch');

gulp.task('default', function() {
	gulp.start(['build','stylus','watch','connect']);
});


gulp.task('connect', function () {
  connect.server({
    root: ['out'], //, 'tmp'],
    port: 8000,
    // livereload: true
  });
});


gulp.task('watch', function () {
    
    watch(['./src/*','./out/*.html'], function () {
    	gulp.start(['build','stylus']);      
    })
});


gulp.task('stylus',function(){
	gulp.src('./src/*.stylus')
    	.pipe(stylus({ 
    		use: nib(), 
    		// compress: true 
    	}))
    	.pipe(gulp.dest('out'));
})


gulp.task('build',function(){
	gulp.src('./src/main.coffee')
		.pipe(webpack({ 
			plugins: [
				// new webpackModule.optimize.UglifyJsPlugin({minimize: true})
			],
			module: {
				loaders: [
					{ test: /\.coffee$/, loader: "coffee" }					
				],
				alias:{
					'':'coffee',
					'cs':'coffee'
				}
			},
			resolveLoaders: {
				alias:{
					'cs':'coffee'
				}
			},
			resolve: {
				extensions: ["", ".web.coffee", ".web.js", ".coffee", ".js"],
				alias:{
					'cs':'coffee'
				},
				modulesDirectories: [ './node_modules','./src' ]
				
			},
			devtool: "source-map",
			output: {
				filename: "bundle.js"
			},
			// externals: {
			// 	"jquery": "jQuery"
			// }
		 }))
        .pipe(gulp.dest('out'));

})



