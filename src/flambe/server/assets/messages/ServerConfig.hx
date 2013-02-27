package flambe.server.assets.messages;

//Unused
@:build(transition9.websockets.Macros.buildWebsocketMessage())
class ServerConfig
{
	public function new (address :String, port :Int)
	{
		this.httpPort = port;
		this.address = address;
	}
	
	@serialize
	public var httpPort :Int;
	
	@serialize
	public var address :String;
}
