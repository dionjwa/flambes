#!/usr/bin/env python

import shutil

# Setup options for display when running waf --help
def options(ctx):
	ctx.load("flambe")

# Setup configuration when running waf configure
def configure(ctx):
	ctx.load("flambe")

# Runs the build!
def build(ctx):
	if ctx.env.debug: print("This is a debug build!")
	
	#Stand alone asset server
	ctx(name="assetserver", 
		features="flambe-server",
		npm_libs="commander websocket",
		main="flambe.server.assets.AssetServer",
		libs="flambe nodejs nodejs_externs remoting node-std hxods macro-tools",
		target="assetserver.js")
	
	# shutil.copy("build/assetserver-server/assetserver.js", "./assetserver.js")
	
