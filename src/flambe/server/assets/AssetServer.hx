package flambe.server.assets;

import flambe.server.assets.ManifestService;

import js.Node;

import js.node.Connect;
import js.node.WebSocketNode;

import transition9.remoting.MiddlewareBuilder;
import transition9.remoting.NodeJsHtmlConnection;

import transition9.websockets.WebsocketRouter;

import flambe.server.assets.messages.ServerConfig;

class AssetServer
{
	public static function createWebsocketRouter(websocketPort :Int) :WebsocketRouter
	{
		var http :NodeHttp = Node.require('http');
		var server = http.createServer(function (req :NodeHttpServerReq, res :NodeHttpServerResp) {
			Log.info(Date.now() + ' Received request for ' + req.url);
			res.writeHead(404);
			res.end();
		});
		
		server.listen(websocketPort, 'localhost', function() {
			Log.info(Date.now() + ' WebsocketRouter [http://localhost:' + websocketPort + "]");
		});
		
		var router = new WebsocketRouter(server);
		
		return router;
	}
	
	public static function getLocalIp () :String
	{
		// trace('Node.os.networkInterfaces()=' + Node.os.networkInterfaces());
		var en1 :Array<NodeNetworkInterface> = Node.os.networkInterfaces().en1;
		if (en1 != null) {
			for (n in en1) {
				if (n.family == "IPv4") {
					return n.address;
				}
			}
		}
		return "127.0.0.1";
	}
	
	public static function main () :Void
	{
		//https://github.com/visionmedia/commander.js
		var program :Dynamic= Node.require('commander');
		program
			.version('Flambe Asset Server (flambes) 0.0.1.  Serving up flaming hot assets since 1903.\n Run in the root of your game project.')
			.option('-p, --port <port>', 'specify the http port, defaults to [8000].  The websocket port is +1.', untyped Number, 8000)
			// .option('-w, --wsport <wsport>', 'specify the websocket port [8001]', untyped Number, 8001)
			.option('-a, --assets <assets>', 'asset folder, defaults to [./assets]', untyped String, "./assets")
			.option('-d, --deploy <deploy>', 'deploy folder, defaults to [./deploy/web]', untyped String, "./deploy/web")
			.parse(Node.process.argv);
  
		var staticFiles = Node.path.join(Node.process.cwd(), program.deploy);
		
		Log.info("Serving http: 0.0.0.0/" + getLocalIp() + ":" + program.port);
		Log.info("Serving   ws: 0.0.0.0/" + getLocalIp() + ":" + (program.port + 1));
		Log.info("Serving asset files from: " + staticFiles);
			
		//Create the websocket listener:
		var router = createWebsocketRouter(program.port + 1);
			
		//Attach the websocket server to the manifest service (also listens to non-socket http requests for haxe remoting)
		var manifestService = new ManifestService(router, program.assets);
		
		//Tell the client which http port to use to download the assets.
		var serverConfig = new ServerConfig(getLocalIp(), program.port);
		router.clientRegistered.connect(function(connection :RouterSocketConnection) {
			router.sendObj(serverConfig, [connection.clientId]);
		});
		
		//Set up the http server
		//http://www.senchalabs.org/connect/
		
		var connect :Connect = Node.require('connect');
		connect.createServer(
			connect.logger('dev')
			,connect.errorHandler({showStack:true, showMessage:true, dumpExceptions:true})
			,connect.favicon()
			// Create the server. Function passed as parameter is called on every request made.
			,new MiddlewareBuilder()
				//Add our example service
				.addRemotingManager(manifestService)
				// .allowJsonFallback()//
				.buildConnectMiddleware()//This can be checked quickly
			,ConnectStatic.Static(connect, staticFiles)
		).listen(program.port, '0.0.0.0');
		
		
		// Node.
		
		// var spawn = require('child_process').spawn,
		// 	ls    = spawn('ls', ['-lh', '/usr']);
		
		// ls.stdout.on('data', function (data) {
		//   console.log('stdout: ' + data);
		// });
		
		// ls.stderr.on('data', function (data) {
		//   console.log('stderr: ' + data);
		// });
		
		// ls.on('exit', function (code) {
		//   console.log('child process exited with code ' + code);
		// });
	}
}
