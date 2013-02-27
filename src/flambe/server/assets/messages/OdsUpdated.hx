package flambe.server.assets.messages;

@:build(transition9.websockets.Macros.buildWebsocketMessage())
class OdsUpdated
{
	public function new (odsName :String, data :Hash<Array<Dynamic>>)
	{
		this.odsName = odsName;
		this.data = data;
	}
	
	@serialize
	public var odsName :String;
	
	@serialize
	public var data :Hash<Array<Dynamic>>;
}
