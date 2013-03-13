package flambe.server.assets.messages;

@:build(transition9.websockets.Macros.buildWebsocketMessage())
class OdsUpdated
{
	#if haxe3
	public function new (odsName :String, data :Map<String, Array<Dynamic>>)
	#else
	public function new (odsName :String, data :Hash<Array<Dynamic>>)
	#end
	{
		this.odsName = odsName;
		this.data = data;
	}
	
	@serialize
	public var odsName :String;
	
	@serialize
	#if haxe3
	public var data :Map<String, Array<Dynamic>>;
	#else
	public var data :Hash<Array<Dynamic>>;
	#end
}
