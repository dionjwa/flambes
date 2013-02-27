package flambe.server.assets;

import flambe.util.SignalConnection;
import flambe.util.Promise;
import flambe.asset.Manifest;
import flambe.asset.AssetEntry;

import flambe.server.services.FileMonitorService;
import flambe.server.services.FileMonitorResult;
import flambe.server.assets.Manifests;
import flambe.server.assets.messages.AssetUpdated;
import flambe.server.assets.messages.OdsUpdated;

import transition9.websockets.WebsocketRouter;

#if macro
import haxe.macro.Expr;
#elseif nodejs
import js.Node;
import js.sys.FileSystem;
#end

using flambe.util.Strings;
using StringTools;
using Lambda;
using flambe.util.Iterators;

/**
  * Monitors changes in asset files.
  * A service, so can be easily added to other servers.
  */
#if !macro
@:build(transition9.remoting.Macros.remotingClass())
class ManifestService extends FileMonitorService
{
	var _websockets :WebsocketRouter;
	var _manifests :Promise<Hash<Array<AssetEntry>>>;
	var _assets :Hash<AssetBlob>; //Key is the file path, used by the FileService
	
	public function new (websockets :WebsocketRouter)
	{
		super();
		haxe.Serializer.USE_ENUM_INDEX=true;
		_assets = new Hash<AssetBlob>();
		_websockets = websockets;
		fileChangedSignal.connect(onFileChangedSignal);
		buildManifests();
	}
	
	@remote
	public function getManifestNames (cb :Array<String>->Void) :Void
	{
		_manifests.get(function(manifests :Hash<Array<AssetEntry>>) {
			cb(manifests.keys().array());		
		});
	}
	
	@remote
	public function getManifest (packName :String, cb :flambe.asset.Manifest->Void) :Void
	{
		_manifests.get(function(manifests :Hash<Array<AssetEntry>>) {
			var manifest = new Manifest(packName);
			for (asset in manifests.get(packName)) {
				manifest.add(asset.name, asset.url, asset.bytes, asset.type);
			}
			cb(manifest);	
		});
	}
	
	@remote
	public function getManifests (cb :Hash<flambe.asset.Manifest>->Void) :Void
	{
		_manifests.get(function(manifests :Hash<Array<AssetEntry>>) {
			var result = new Hash<Manifest>();
			for (packName in manifests.keys()) {
				var manifest = new Manifest(packName);
				result.set(packName, manifest);
				for (asset in manifests.get(packName)) {
					manifest.add(asset.name, asset.url, asset.bytes, asset.type);
				}	
			}
			cb(result);
		});
	}
	
	function buildManifests() :Void
	{
		unregisterAll(function(ignored :Bool) {});
		_manifests = new Promise();
		//Build manifest, and monitor all the files
		_assets = new Hash();
		
		var newManifests = Manifests.createManifests(Manifests.findAssetPath());
		
		trace('newManifests=' + Node.stringify(newManifests));
		
		for (packName in newManifests.keys()) {
			for (asset in newManifests.get(packName)) {
				var filePath = asset.url.split("?")[0];
				var assetBlob = new AssetBlob(packName, asset);
				_assets.set(filePath, assetBlob);
				
				this.registerFile(filePath, function(result :FileMonitorResult) :Void {
					Log.info("Watching file " + filePath);
				});
			}
		}
		
		_manifests.result = newManifests;
	}
	
	function onFileChangedSignal(filePath :String) :Void
	{
		var blob :AssetBlob = _assets.get(filePath);
		if (blob == null) {
			Log.error("No asset matching", ["filePath", filePath]);
			return;
		}
		//Replace with the new AssetEntry
		var updatedEntry = Manifests.createAssetEntry(blob.asset.name, blob.asset.url, filePath);
		_assets.set(filePath, new AssetBlob(blob.pack, updatedEntry));
	
		if (filePath.endsWith(".ods")) {
			//Send the parsed ODS file
			//The updated ODS file is not copied. Should it be?  Probably not since it could be downloaded
			//and this might not be desirable
			var update = function() {
				var data = flambe.server.services.OdsRuntimeParser.parse(filePath);
				_websockets.sendObj(new OdsUpdated(updatedEntry.name, data));
			}
			if (FileSystem.stat(filePath).size == 0) {
				Node.setTimeout(update, 100);
			} else {
				update();
			}
		} else {
			//Update the asset entry
			Log.warn("Asset changed ", ["asset", updatedEntry]);
			//Copy to the deploy folder
			var target = FileSystem.join("deploy/web", filePath);
			Log.warn("Copying ", ["from", filePath, "to", target]);
			js.sys.io.File.copy(filePath , target);
			//Broadcast the changed asset info
			var update = new AssetUpdated(blob.pack, updatedEntry);
			Log.warn("update: " + Node.stringify(update));
			_websockets.sendObj(update);
		}
	}
}
#else
class ManifestService extends FileMonitorService{}
#end

class AssetBlob
{
	public function new (pack :String, asset :AssetEntry)
	{
		this.pack = pack;
		this.asset = asset;
	}
	public var asset (default, null):AssetEntry;
	public var pack (default, null):String;
}
