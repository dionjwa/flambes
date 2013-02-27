package flambe.server.assets.messages;

import flambe.asset.AssetEntry;

@:build(transition9.websockets.Macros.buildWebsocketMessage())
class AssetUpdated
{
	public function new (manifestId :String, asset :AssetEntry)
	{
		this.manifestId = manifestId;
		this.asset = asset;
	}
	
	@serialize
	public var manifestId :String;
	
	@serialize
	public var asset :AssetEntry;
}
