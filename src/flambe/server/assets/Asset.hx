package flambe.server.assets;

typedef Asset = {
	var name :String;
	var pack :String;
	var md5 :String;
	var bytes :Int;
	
	@:optional
	var path :String;
}
