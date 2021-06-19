import vibe.vibe;
import core.thread : Fiber;
import std.stdio;
import std.conv;
import novelreader.api;
import novelreader.database;
import novelreader.databasebuilder;
import novelreader.webservice;

/++
 Main
++/
void main()
{
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
					runWebServer(db);
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
void runWebServer(NovelDB db)
{
    auto router = new URLRouter;
    auto settings = new HTTPServerSettings;
    settings.port = 8080;
    settings.bindAddresses = [ "::1", "127.0.0.1"];
    settings.sessionStore = new MemorySessionStore;
    router.registerRestInterface( new RestAPI( db));
    router.registerWebInterface( new WebService( db));
    auto listener = listenHTTP( settings, router);
    scope (exit)
    {
        listener.stopListening();
    }

    logInfo( "Please open http://127.0.0.1:8080/ in your browser.");
    runApplication();
}