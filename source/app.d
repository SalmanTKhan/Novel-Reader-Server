import vibe.vibe;
import core.thread : Fiber;
import std.stdio;
import std.conv;
import novelreader.api;
import novelreader.database;
import novelreader.databasebuilder;
import novelreader.webservice;

import simpleconfig;

struct Config
{
	@cli("ipv4") @cfg("ipv4")
	string ipv4 = "127.0.0.1"; /// Address to bind web server to
	@cli("ipv6") @cfg("ipv6")
	string ipv6 = "::1"; /// Address to bind web server to
	@cli("port") @cfg("port")
	ushort port = 8080; /// Port to bind web server to
	@cli("api") @cfg("api")
	bool api = true; /// Port to bind web server to
	
	void finalizeConfig ()
	{
		// Additional Checks (Unused)
	}
}

/++
 Main
++/
void main()
{
	Config config;
    readConfiguration(config);
    NovelDB db = new NovelDB();
    NovelDatabaseBuilder builder = new NovelDatabaseBuilder(db);
	string line = "";
    char choice;

	for(;;) {
		writeln("B)uild initial database.");
        writeln("C)hapter database builder.");
		writeln("R)un Web Server.");
		writeln("Q)uit.");
		write("Select an option: ");
		
		line = readln().replace("\n", "");
		if (line.length > 0) {
			choice = line.strip.to!char;

			switch (choice.toUpper()){
				case('B'):
					builder.buildDB();
					break;
	        	case('C'):
					builder.buildChapterTextDatabase();
					break;
				case('R'):
					runWebServer(db, config);
					return;
				case('Q'):
					return;
				default:
					continue;
			}
		}
	}
}

/++
 Run Vibe.d Web Server
++/
void runWebServer(NovelDB db, Config config)
{	
    auto router = new URLRouter;
    auto settings = new HTTPServerSettings;
    settings.port = config.port;
	if (config.ipv6 != "" && config.ipv4 != "")
		settings.bindAddresses = [config.ipv6, config.ipv4];
	else if (config.ipv6 != "")
		settings.bindAddresses = [config.ipv6];
	else if (config.ipv4 != "")
		settings.bindAddresses = [config.ipv4];
    settings.sessionStore = new MemorySessionStore;
	if (config.api) {
		logInfo("Enabling API access");
    	router.registerRestInterface( new RestAPI( db));
	}
    router.registerWebInterface( new WebService( db));
    auto listener = listenHTTP( settings, router);
    scope (exit)
    {
        listener.stopListening();
    }

	if (config.ipv4 != "")
    	logInfo( "Please open http://%s:%s/ in your browser.", config.ipv4, config.port);
	if (config.ipv6 != "")
		logInfo( "Please open http://%s:%s/ in your browser.", config.ipv6, config.port);
    runApplication();
}