package flambe.server.services;

import flambe.util.Signal1;
#if !macro
import js.Node;
#end

/**
 * Watches for changes in files and broadcasts a changed signal. 
 */
class FileMonitorService
{
	public var fileChangedSignal (default, null):Signal1<String>;
	var _watchedFiles :Hash<NodeFSWatcher>;
	public function new ()
	{
		_watchedFiles = new Hash();
		fileChangedSignal = new Signal1();
	}

	/**
	 * Watches this file for changes.  Notifies listeners 
	 * when the file is modified.
	 */
	@remote
	public function registerFile (fileName :String, cb :flambe.server.services.FileMonitorResult->Void) :Void
	{
		if (!_watchedFiles.exists(fileName)) {
			Node.fs.exists(fileName, function(exists) {
				if (exists) {
					var options :NodeWatchOpt = {persistent:true};
					// var watcher :NodeFSWatcher = Node.fs.watch(fileName, {persistent: true}, onFileChanged);
					var watcher :NodeFSWatcher = Node.fs.watch(fileName, options, function(event :String, ?ignored :String) {
						//Some programs save a file with an intermediate rename step.
						//This breaks the NodeFSWatcher, so we have to watch the new file
						if (event == 'rename') {
							var obsoleteWatcher = _watchedFiles.get(fileName);
							_watchedFiles.remove(fileName);
							registerFile(fileName, function(status :FileMonitorResult) :Void {
								Log.warn(fileName + " renamed, status: " + status);
							});
						} else {
							onFileChanged(event, fileName);
						}
					});
					_watchedFiles.set(fileName, watcher);
					cb({status:"ok"});
				} else {
					cb({status:"file_doesn't_exist"});
				}
			});
			
			
		} else {
			cb({status:"file_already_watched"});
		}
	}
	
	@remote
	public function unregisterFile (fileName :String, cb :Bool->Void) :Void
	{
		if (_watchedFiles.exists(fileName)) {
			Log.info("Unwatching " + fileName);
			_watchedFiles.get(fileName).close();
			_watchedFiles.remove(fileName);
			cb(true);
		} else {
			cb(false);
		}
	}
	
	@remote
	public function unregisterAll (cb :Bool->Void) :Void
	{
		for(f in _watchedFiles) {
			f.close();
		}
		_watchedFiles = new Hash();
		cb(true);
	}
	
	//event is either 'rename' or 'change',
	//filename is the name of the file which triggered the event.
	function onFileChanged (event :String, fileName :String)
	{
		Log.info("onFileChanged", ["fileName", fileName, "event", event]);
		//Broadcast this to all listeners
		fileChangedSignal.emit(fileName);
	}
}
