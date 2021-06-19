module novelreader.databasebuilder;
import std.stdio;
import std.conv;
import novelreader.database;
import novelreader.model;
import novelreader.parser;

/++ Novel Database Builder
 Build novel database using a parser (currently hardcoded with NovelFull)
++/
class NovelDatabaseBuilder {
    NovelDB db; /// Novel Database
    Novel[] novels; /// Novels
    this(NovelDB _db) {
        db = _db;
        novels = db.getNovels();
    }

    void testParser() {
        auto parser = new NovelFull;
        auto novel = parser.parseNovel("https://novelfull.com/swallowed-star.html");
        Chapter[string] chapterMap;
        const auto cachedChaptersCount = db.getChapterCount( 54);
        if (novel.chapter_count > 0 && novel.chapter_count == cachedChaptersCount) {
            writeln( `Skipping novel because chapters are counted ` ~ novel.title);
        } else {
            writeln( `Parsing Novel ` ~ novel.title ~ ` ` ~ novel.url ~ ` chapter count: ` ~ to!string( novel.chapter_count) ~ ` cached chapter count: ` ~ to!string(cachedChaptersCount));
            foreach(i, chapter; novel.chapters) {
                if (chapter.url !in chapterMap) {
                    chapterMap[chapter.url] = chapter;
                } else {
                    writeln(`Duplicate chapter found ` ~ chapter.url);
                }
            }
        }
        writeln(`Updated Novel ` ~ novel.title ~ ` ` ~ novel.url ~ ` chapter count: ` ~ to!string( novel.chapter_count));
    }

    /++ Build a novel database
     - First check database
    ++/
    void buildDB() {
        if (novels.length == 0) {
            buildInitialDatabase();
        } else {
            buildFullDatabase();
        }
        buildChapterTextDatabase();
    }

    /// Build Initial Database for NRS using the 800 most popular novels
    void buildInitialDatabase() {
        writeln( `Building Initial Database`);
        buildNovelDatabase("https://novelfull.com/index.php/most-popular?page=1", 41);
    }

    /// Build Latest Release Database for NRS using the 800 latest updated novels
    void buildLatestReleasesDatabase() {
        writeln( `Building Latest Release Database`);
        buildNovelDatabase("https://novelfull.com/index.php/latest-release-novel?page=1");
        buildFullDatabase();
    }

    /// Build the Novel Database from a specific url and range of pages
    void buildNovelDatabase(string url, int lastPage = 42) {
        auto parser = new NovelFull;
        Novel[] tempNovels;
        foreach (i; 1..lastPage) {
            tempNovels = parser.parseNovels( url, i);
            foreach (novel; tempNovels) {
                novel.id = db.insertNovel( novel);
            }
            writeln( `Completed page : `~ to!string(i) ~ ` loaded ` ~ to!string( tempNovels.length));
            novels ~= tempNovels;
        }
    }

    void fixChapterCount() {
        foreach (i, novel; novels) {
            const auto cachedChaptersCount = db.getChapterCount( novel.id);
            if (novel.chapter_count == 0 && cachedChaptersCount != 0) {
                novel.chapter_count = cachedChaptersCount;
                db.insertNovel( novel);
            }
        }
    }

    /// Parse Novel Additional Data (Genres/Aliases/Summary/Status) and Chapters
    void buildFullDatabase() {
        writeln( `Building Full Database`);
        auto parser = new NovelFull;
        Novel parsedNovel = null;
        Novel[] fullNovels;
        foreach (i, novel; novels) {
            const auto cachedChaptersCount = db.getChapterCount( novel.id);
            if (novel.chapter_count > 0 && novel.chapter_count == cachedChaptersCount) {
                writeln( `Skipping novel because chapters are counted ` ~ to!string( i) ~ ` / ` ~ to!string( novels.length) ~ ` ` ~ novel.title);
            } else {
                writeln( `Parsing Novel ` ~ to!string( i+1) ~ ` / ` ~ to!string( novels.length) ~ ` ` ~ novel.title ~ ` ` ~ novel.url ~ ` chapter count: ` ~ to!string( novel.chapter_count) ~ ` cached chapter count: ` ~ to!string(cachedChaptersCount));
                parsedNovel = parser.parseNovel( novel.url);
                parsedNovel.id = db.insertNovel( parsedNovel);
                Chapter[string] chapterMap;
                foreach (chapter; parsedNovel.chapters) {
                    if (chapter.url !in chapterMap) {
                        chapterMap[chapter.url] = chapter;
                        chapter.novel_id = parsedNovel.id;
                        chapter.id = db.insertChapter( chapter);
                        writeln(`Added chapter to database ` ~ chapter.toString());
                    } else {
                        writeln(`Skipped chapter because it's a duplicate ` ~ chapter.toString());
                    }
                }
                fullNovels ~= parsedNovel;
                writeln(`Updated Novel ` ~ to!string( i+1) ~ ` / ` ~ to!string( novels.length) ~ ` ` ~ novel.title ~ ` ` ~ novel.url ~ ` chapter count: ` ~ to!string( novel.chapter_count));
            }
        }
    }

    /// Parse missing chapters' text
    void buildChapterTextDatabase() {
        auto parser = new NovelFull;
        auto chapters = db.getChaptersMissingText();
        foreach (i, chapter; chapters) {
            writeln( `Parsing chapter: ` ~ to!string(i) ~ ` / ` ~ to!string(chapters.length) ~ ` ` ~ chapter.title ~ ` ` ~ chapter.url);
            chapter.text = parser.parseChapter( chapter.url);
            db.insertChapter( chapter);
        }
    }
}