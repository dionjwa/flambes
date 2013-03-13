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

import sys.FileSystem;

#if macro
import haxe.macro.Expr;
#elseif (nodejs || nodejs_std)
import js.Node;
#end

using flambe.util.Strings;
using StringTools;
using Lambda;

/**
  * Monitors changes in asset files.
  * A service, so can be easily added to other servers.
  */
#if !macro
@:build(transition9.remoting.Macros.remotingClass())
class ManifestService extends FileMonitorService
{
	var _websockets :WebsocketRouter;
	var _assetPath :String;
	#if haxe3
		var _manifests :Promise<Map<String, Array<AssetEntry>>>;
		var _assets :Map<String, AssetBlob>; //Key is the file path, used by the FileService
	#else
		var _manifests :Promise<Hash<Array<AssetEntry>>>;
		var _assets :Hash<AssetBlob>; //Key is the file path, used by the FileService
	#end
	
	
	public function new (websockets :WebsocketRouter, assetPath :String)
	{
		super();
		haxe.Serializer.USE_ENUM_INDEX=true;
		_assetPath = assetPath;
		#if haxe3
			_assets = new Map<String, AssetBlob>();
		#else
			_assets = new Hash<AssetBlob>();
		#end
		_websockets = websockets;
		fileChangedSignal.connect(onFileChangedSignal);
		buildManifests();
	}
	
	@remote
	public function getManifestNames (cb :Array<String>->Void) :Void
	{
		#if haxe3
		_manifests.get(function(manifests :Map<String, Array<AssetEntry>>) {
		#else
		_manifests.get(function(manifests :Hash<Array<AssetEntry>>) {
		#end
			cb({iterator:manifests.keys}.array());		
		});
	}
	
	@remote
	public function getManifest (packName :String, cb :flambe.asset.Manifest->Void) :Void
	{
		#if haxe3
		_manifests.get(function(manifests :Map<String, Array<AssetEntry>>) {
		#else
		_manifests.get(function(manifests :Hash<Array<AssetEntry>>) {
		#end
			var manifest = new Manifest(packName);
			for (asset in manifests.get(packName)) {
				manifest.add(asset.name, asset.url, asset.bytes, asset.type);
			}
			cb(manifest);	
		});
	}
	
	@remote
	#if haxe3
	public function getManifests (cb :Map<String, flambe.asset.Manifest>->Void) :Void
	#else
	public function getManifests (cb :Hash<flambe.asset.Manifest>->Void) :Void
	#end
	{
		#if haxe3
		_manifests.get(function(manifests :Map<String, Array<AssetEntry>>) {
			var result = new Map<String, Manifest>();
		#else
		_manifests.get(function(manifests :Hash<Array<AssetEntry>>) {
			var result = new Hash<Manifest>();
		#end
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
		unregisterAll(function(_) {});
		_manifests = new Promise();
		//Build manifest, and monitor all the files
		_assets = new Map();
		
		Log.info("Asset path: " + _assetPath);
		var newManifests = Manifests.createManifests(_assetPath);
		
		// trace('newManifests=' + Node.stringify(newManifests));
		
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
			sys.io.File.copy(filePath , target);
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
