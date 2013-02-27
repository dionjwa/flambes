package flambe.asset;

import flambe.platform.BasicAssetPackLoader;

import flambe.server.assets.messages.AssetUpdated;
import flambe.server.assets.messages.OdsUpdated;
import flambe.server.assets.messages.ServerConfig;

import flambe.util.Signal2;

import transition9.websockets.WebsocketClient;

/**
  * Client side reloading assets from a remote AssetServer
  */
class AssetReloader
{
	public static var odsSignal :Signal2<String, Array<Dynamic>> = new Signal2<String, Array<Dynamic>>();
	
	public static function setupAssetReloading (loadEntry :AssetEntry->Void, manifest :Manifest) :Void
	{
		haxe.Serializer.USE_ENUM_INDEX=true;
		
		if (odsSignal == null) {
			odsSignal = new Signal2<String, Array<Dynamic>>();
		}
		
		var wsport :Int = Std.int(js.Lib.window.location.port) + 1;
		var websocketUrl = "ws://" + js.Lib.window.location.hostname + ":" + wsport;
		Log.info('Websocket URL=' + websocketUrl);
		
		var websocketClient = new transition9.websockets.WebsocketClient(websocketUrl);
		
		var r = ~/\?v=.*/; // g : replace all instances
		
		websocketClient.registerMessageHandler(function(msg :AssetUpdated) :Void {
			Log.info("Received AssetUpdated: ", ["msg", Std.string(msg)]);
			var foundEntry = false;
			for (entry in manifest) {
				if (entry.name == msg.asset.name) {
					Log.info("Reloading asset entry:", ["updatedAssetEntry", msg.asset]);
					loadEntry(msg.asset);
					foundEntry = true;
					break;
				}
			}
			if (!foundEntry) {
				Log.warn("No AssetEntry matching", ["name", msg.asset.name]);
			}
		});
		
		websocketClient.registerMessageHandler(function(msg :OdsUpdated) :Void {
			Log.info("Received OdsUpdated: ", ["msg", Std.string(msg)]);
			for (dataKey in msg.data.keys()) {
				odsSignal.emit(dataKey, msg.data.get(dataKey));
			}
		});
		
		websocketClient.registerMessageHandler(function(msg :ServerConfig) :Void {
			Log.info("Received " + Type.getClassName(Type.getClass(msg)) + ": ", ["msg", Std.string(msg)]);
		});
	}
}
