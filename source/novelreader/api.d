module novelreader.api;
import novelreader.model;
import novelreader.database;
import vibe.vibe;
import std.stdio;
import std.conv;

interface IRest
{
    @path( "/api/v1/chapters/:novel_id")
    Chapter[] getChapters(int _novel_id);

    //@path( "/api/v1/chapters/:novel_url")
    //Chapter[] getChapters(string _novel_url);

    @path( "/api/v1/novels")
    Novel[] getNovels();

    //@path( "/api/v1/novel/:url")
    //Novel getNovel(string _url);

    @path( "/api/v1/add-chapter")
    @method( HTTPMethod.POST)
    int addChapter(string title);
}

class RestAPI: IRest
{
    Novel[] novels;
    NovelDB db;

    this(Novel[] _novels) {
        novels = _novels;
    }

    this(NovelDB _db) {
        db = _db;
        novels = db.getNovels();
    }

    Chapter[] getChapters(int _novel_id)
    {
        writeln(`getChapters called with novel id: ` ~ to!string(_novel_id));
        return db.getChaptersSimple(_novel_id);
    }

    @safe
    Novel[] getNovels()
    {
        return novels;
    }

    @safe
    int addNovel(string title)
    {
        import std.algorithm : map, max, reduce;
        //return newId;
        return -1;
    }

    @safe
    int addChapter(string title)
    {
        import std.algorithm : map, max, reduce;
        // Generate the next highest ID
        //auto newId = chapters_.map!(x => x.id).reduce!max + 1;
        //chapters_ ~= new Chapter(title, newId);
        //return newId;
        return -1;
    }
}