[haxe]:http://http://haxe.org
[haxe3]:http://haxe.org/manual/haxe3
[flambe]:http://lib.haxe.org/p/flambe
[wafl]:https://github.com/aduros/flambe/wiki/Wafl
[nodejs]:http://nodejs.org/

# flambes: Automatic asset updater and server for [flambe][flambe].

For fast game development iterations, flambes detect changes in assets, e.g. images, notify the client, and the client will automatically update those assets at runtime.

As a bonus, it will parse change Open Office spreadsheet documents, and push the changed file as JSON to the client.  


## Howto:

This library is at the currently in the experimental stage and is written for [Haxe 3][haxe3].

Instructions:

Clone this repo and the forked flambe repo:

	git clone --recursive git://github.com/dionjwa/flambes.git
	cd flambe/lib
	git clone git://github.com/dionjwa/flambe.git
	cd flambe
	git checkout haxe3
	haxelib dev flambe [path to current dir]
	cd ../..
	
Then build the demo.  This assumes you have [wafl][wafl] already installed.

	cd demo
	wafl configure --debug
	



