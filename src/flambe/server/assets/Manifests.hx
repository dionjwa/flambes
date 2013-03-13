package flambe.server.assets;

#if js
import js.Lib;
#end

import sys.FileSystem;

#if macro

import sys.io.File;

import haxe.macro.Expr;
import haxe.macro.Context;
import haxe.macro.Type;
#else
// import sys.FileSystem;
import js.Node;
#end

import haxe.rtti.Meta;

import flambe.asset.Manifest;
import flambe.asset.AssetEntry;

using flambe.util.Strings;
using Lambda;
using StringTools;
using Type;

#if !haxe3
typedef Map<Ignored,T> = Hash<T>
#end

class Manifests
{
	public static function createAssetEntry (name :String, url :String, fullPath :String) :AssetEntry
	{
		url = url.split("?")[0];
		var type = inferType(url);
		
		if (type == Image || type == Audio) {
			// If this an asset that not all platforms may support, trim the extension from
			// the name. We'll only load one of the assets if this creates a name collision.
			name = name.removeFileExtension();
		}
		
		#if macro
		url = url + "?v=" + Context.signature(File.getBytes(fullPath));
		var bytes = FileSystem.stat(fullPath).size;
		#elseif nodejs
		//Assume nodejs
		url = url + "?v=" + sys.FileSystem.signature(fullPath);
		var bytes = sys.FileSystem.stat(fullPath).size;
		#else
		var url = "";
		var bytes = 0;
		#end
		
		var entry = new AssetEntry(name, url, type, bytes);
		return entry;
	}
	
	public static function readDirectoryNoHidden (dir :String) :Array<String>
	{
		if (dir.fastCodeAt(dir.length - 1) == "/".code) {
		 // Trim off the trailing slash. On Windows, FileSystem.exists() doesn't find directories
		 // with trailing slashes?
		 dir = dir.substr(0, -1);
		}
		return FileSystem.exists(dir) && FileSystem.isDirectory(dir) ?
			FileSystem.readDirectory(dir)
				.filter(function (file) return (!(file.fastCodeAt(0) == ".".code || file.endsWith(".cache")))).array()
				:
			cast [];
	}
	
	public static function readRecursive (root, dir = "")
	{
		var result = [];
		for (file in readDirectoryNoHidden(root + "/" + dir)) {
			var fullPath = root + "/" + dir + "/" + file;
			var relPath = if (dir == "") file else dir + "/" + file;
			if (FileSystem.isDirectory(fullPath)) {
				result = result.concat(readRecursive(root, relPath));
			} else {
				result.push(relPath);
			}
		}
		return result;
	}
	
	#if (nodejs && !macro)
	public static function findAssetPath (?root :String) :String
	{
		if (root == null) {
			root = "./";
		}
		
		if (!FileSystem.isDirectory(root)) {
			return null;
		}
		
		for (child in FileSystem.readDirectory(root)) {
			if (child == "assets") {
				return Node.path.join(root, child);
			}
		}
		
		for (child in FileSystem.readDirectory(root)) {
			var fullPath = Node.path.join(root, child);
			if (FileSystem.isDirectory(fullPath)) {
				var path = findAssetPath(fullPath);
				if (path != null) {
					return path;
				}
			}
		}
		return null;
	}
	#end
	
	public static function createManifests (assetPath :String) :Map<String, Array<AssetEntry>>
	{
		
		var set = new Map<String, Array<AssetEntry>>();
		
		for (packName in readDirectoryNoHidden(assetPath)) {
			var entries :Array<AssetEntry> = [];
			var manifestPath = FileSystem.join(assetPath, packName);
			if (FileSystem.isDirectory(manifestPath)) {
				for (file in readRecursive(manifestPath)) {
					var path = FileSystem.join(manifestPath, file);
					var entry = createAssetEntry(file, assetPath + "/" + packName + "/" + file, path);
					entries.push(entry);
				}
				// Build a pack with a list of file entries
				set.set(packName, entries);
			}
		}
		return set;
	}

	private static function inferType (url :String) :AssetType
	{
		var extension = url.split("?")[0].getFileExtension();
		if (extension != null) {
			switch (extension.toLowerCase()) {
				case "png", "jpg", "gif": return Image;
				case "ogg", "m4a", "mp3", "wav": return Audio;
			}
		}
		return Data;
	}
}
