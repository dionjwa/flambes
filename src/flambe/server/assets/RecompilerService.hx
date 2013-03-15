package flambe.server.assets;

import flambe.util.SignalConnection;
import flambe.util.Promise;

import flambe.server.services.FileMonitorService;
import flambe.server.services.FileMonitorResult;

import transition9.websockets.WebsocketRouter;
import flambe.server.assets.messages.ClientReload;

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
  * Recompiles code on changes in *.hx files and notifies clients to reload.
  */
class RecompilerService extends FileMonitorService
{
	var _websockets :WebsocketRouter;
	var _srcPaths :Array<String>;
	var _recompileCommand :Array<String>;
	var _recompileTimeout :Int;
	var _isCompiling :Bool;
	
	public function new (websockets :WebsocketRouter, srcPaths :Array<String>,  recompileCommand :Array<String>)
	{
		super();
		_websockets = websockets;
		Log.warn("recompileCommand: " + recompileCommand);
		_recompileTimeout = 0;
		_isCompiling = false;
		_srcPaths = srcPaths;
		_recompileCommand = recompileCommand;
		Log.info("RecompilerService:");
		fileChangedSignal.connect(onFileChangedSignal);
		watchSourceFiles();
		doRecompileCommand();
	}
	
	function watchSourceFiles () :Void
	{
		for (sp in _srcPaths) {
			for (file in FileSystem.readRecursive(sp, function(f :String) { return f.endsWith(".hx");})) {
				file = FileSystem.join(sp, file);
				registerFile(file, function(result :FileMonitorResult) :Void {
					if (result.status == "ok") {
						Log.info("        Watching source file " + file);
					} else {
						Log.error("        Watching source file " + file + ", result: " + result.status);
					}
				});
			}	
		}
	}
	
	function doRecompileCommand()
	{
		_isCompiling = true;
		var commandTokens = _recompileCommand.copy();
		var command = commandTokens.shift();
		var args = commandTokens;
		Log.info("command: " + command);
		Log.info("args: " + args);
		
		var childProcess = Node.childProcess.spawn(command, args);
		
		childProcess.stdout.on('data', function (data) {
			Log.info('stdout: ' + data);
		});
		
		childProcess.stderr.setEncoding('utf8');
		childProcess.stderr.on('data', function (data) {
			Log.error('stderr: ' + data);
		});
		
		childProcess.once('close', function (code) {
			Log.info('child process exited with code ' + code);
			_isCompiling = false;
			_websockets.sendObj(new ClientReload());
		});
	}
	
	function queueCompileCommand()
	{
		if (_isCompiling) {
			if (_recompileTimeout <= 0) {
				_recompileTimeout = Node.setTimeout(queueCompileCommand, 100);
			}
		} else {
			doRecompileCommand();
		}
	}
	
	function onFileChangedSignal(filePath :String)
	{
		trace(filePath + " changed");
		if (_recompileTimeout > 0) {
			Node.clearTimeout(_recompileTimeout);
			_recompileTimeout = 0;
		}
		_recompileTimeout = Node.setTimeout(queueCompileCommand, 100);
	}
}

