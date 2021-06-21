module novelreader.database;
import novelreader.model;
import taskdesigns.sqlite;
import arsd.sqlite;
import std.stdio;
import std.conv;
import std.array;
import std.base64;
import std.zlib;

/// Novel Database Interface
interface NovelDatabase {
    /// Insert Novel to Database
    int insertNovel(Novel novel);
    /// Delete Novel from Database
    void deleteNovel(int id);
    /// Get Novel from Database
    Novel getNovel(int id);
    Novel[] getNovels();
    Novel[] getNovels(string title, int limit, int offset);
    Chapter getChapter(int id);
    Chapter[] getChapters(int novel_id);
    Chapter[] getChaptersSimple(int novel_id, int limit, int offset);
    /// Insert Chapter to Database
    int insertChapter(Chapter chapter);
    int getChapterCount(int novel_id);
}

/// User Database Interface
interface UserDatabase {
    /// Insert User
    int insertUser(User user);
    /// Get User
    User getUser(string username);
}

interface ReadHistoryDatabase {
    /// Insert Read History
    int insertReadHistory(ReadHistory history);
    ReadHistory getReadHistory(int id);
    ReadHistory getReadHistory(int user_id, int novel_id);
    ReadHistory[] getUserHistory(int user_id); /// Get User History
}

/// Novel table structure representation
struct NovelTable {
    Table table = new Table( "novels"); /// Novels table
    Column!int id = new Column!int( "id", false); /// Novel id column
    Column!string title = new Column!string( "title", false); /// Novel title column
    Column!string url = new Column!string( "url", false); /// Novel url column
    Column!string cover_url = new Column!string( "cover_url"); /// Novel cover url column
    Column!string author = new Column!string( "author"); /// Novel author column
    Column!string aliases = new Column!string( "aliases"); /// Novel aliases column
    Column!string summary = new Column!string( "summary"); /// Novel summary column
    Column!string genres = new Column!string( "genres"); /// Novel genres column
    //Column!string type = new Column!string( "type"); /// Novel type column
    Column!int status = new Column!int( "status"); /// Novel status column
    Column!int chapter_count = new Column!int( "chapter_count"); /// Novel chapter count column
    static ~this(){}
}

/// Chapter table structure representation
struct ChapterTable {
    Table table = new Table( "chapters"); /// Chapters table
    Column!int id = new Column!int( "id", false); /// Chapter id column
    Column!string title = new Column!string( "title", false); /// Chapter title
    Column!string url = new Column!string( "url", false); /// Chapter url
    Column!int position = new Column!int( "position", false); /// Chapter position
    Column!string text = new Column!string( "text"); /// Chapter text
    Column!int novel_id = new Column!int( "novel_id"); /// Associated novel id
    static ~this(){}
}

///User Table
struct UserTable {
    Table table = new Table( "users"); /// Table name
    Column!int id = new Column!int( "id", false); /// ID
    Column!string username = new Column!string( "username", false); /// Username
    Column!string password_hash = new Column!string( "password_hash", false); /// Password Hash
    Column!string email = new Column!string( "email", false); /// Email
    Column!int type = new Column!int( "type", false); /// Type (Account/User Type)
    Column!string last_ip = new Column!string( "last_ip", false); /// Last IP
}

/// Chapter table structure representation
struct ReadHistoryTable {
    Table table = new Table( "readhistory"); /// Table name: readhistory
    Column!int id = new Column!int( "id", false); /// Read history id column
    Column!int user_id = new Column!int( "user_id"); /// Read history user id column
    Column!int novel_id = new Column!int( "novel_id"); /// Read history novel id column
    Column!int chapter_id = new Column!int( "chapter_id"); /// Read history chapter id column
    Column!string last_read_date = new Column!string( "last_read_date"); /// Read history last read date timestamp column
    static ~this(){}
}

/// SQLite Implementation of the Novel Database
class NovelDB: NovelDatabase,UserDatabase,ReadHistoryDatabase {
    Database db; /// Database

    this(string dbName = "data") {
        db = new Sqlite( dbName~".db");
        createNovelTable();
        createChapterTable();
        createUserTable();
        createReadHistoryTable();
    }

    /++ Create Novel Table
     - Creates a table in database
    ++/
    void createNovelTable(bool requiresDrop = false) {
        if (requiresDrop)
            db.query( NovelTable().table.drop().asSQL());
        db.query( NovelTable().table.create( (it) {
            auto table = NovelTable();
            it.column( table.id, true, false, true);
            it.column( table.title);
            it.column( table.url);
            it.column( table.cover_url);
            it.column( table.author);
            it.column( table.aliases);
            it.column( table.summary);
            it.column( table.genres);
            //it.column( table.type);
            it.column( table.status);
            it.column( table.chapter_count);
        }).asSQL());
    }
    
    /++ Create Chapter Table
     - Creates a table in database
    ++/
    void createChapterTable(bool requiresDrop = false) {
        if (requiresDrop)
            db.query( ChapterTable().table.drop().asSQL());
        db.query( ChapterTable().table.create( (it) {
            auto table = ChapterTable();
            it.column( table.id, true, false, true);
            it.column( table.title);
            it.column( table.url);
            it.column( table.position);
            it.column( table.text);
            it.column( table.novel_id);
        }).asSQL());
    }

    /++ Create User Table
     - Creates a table in database
    ++/
    private void createUserTable(bool requiresDrop = false) {
        if (requiresDrop)
            db.query( UserTable().table.drop().asSQL());
        db.query( UserTable().table.create( (it) {
            auto table = UserTable();
            it.column( table.id, true, false, true);
            it.column( table.username);
            it.column( table.password_hash);
            it.column( table.email);
            it.column( table.last_ip);
            it.column( table.type);
        }).asSQL());
    }

    /// Create Read History Table
    private void createReadHistoryTable(bool requiresDrop = false) {
        if (requiresDrop)
            db.query( ReadHistoryTable().table.drop().asSQL());
        db.query( ReadHistoryTable().table.create( (it) {
            auto table = ReadHistoryTable();
            it.column( table.id, true, false, true);
            it.column( table.user_id);
            it.column( table.novel_id);
            it.column( table.chapter_id);
            it.column( table.last_read_date);
        }).asSQL());
    }

    void deleteNovel(int novel_id) {
        db.query( NovelTable().table.deleteStatement().where( NovelTable().id.eq( novel_id)).asSQL());
        deleteChapters(novel_id);
    }

    void deleteChapters(int novel_id) {
        db.query( ChapterTable().table.deleteStatement().where( ChapterTable().novel_id.eq( novel_id)).asSQL());
    }

    @trusted
    Novel getNovel(int id)
    {
        Novel novel = null;
        auto novel_table = NovelTable();
        foreach (result; db.query( novel_table.table.select().where( novel_table.id.eq( id)).asSQL())) {
            novel = getNovel( result);
        }
        return novel;
    }

    Novel getNovel(string identifier)
    {
        Novel novel = null;
        auto novel_table = NovelTable();
        foreach (result; db.query( novel_table.table.select().where( novel_table.url.contains( identifier)).asSQL())) {
            novel = getNovel( result);
        }
        return novel;
    }

    @trusted
    Novel[] getNovels(string title = "", int limit = 0, int offset = 0)
    {
        Novel[] novels;
        Novel novel = null;
        auto novel_table = NovelTable();
        auto sql = "";
        if (title.empty()) {
            sql = novel_table.table.select().limitOffset(limit, offset).asSQL();
        } else {
            sql = novel_table.table.select().where( novel_table.title.contains( title)).limitOffset(limit, offset).asSQL();
        }
        foreach (result; db.query( sql)) {
            novel = getNovel( result);
            novels ~= novel;
            novel = null;
        }
        return novels;
    }

    private Novel getNovel(Row result) {
        Novel novel = new Novel();
        novel.id = to!int( result[0]);
        novel.title = result[1];
        novel.url = result[2];
        novel.cover_url = result[3];
        novel.author = result[4];
        novel.aliases = result[5];
        novel.summary = result[6];
        novel.genres = result[7];
        //novel.type = result[8];
        if (!result[8].empty()) {
            novel.status = to!int( result[8]);
        }
        if (result[9] != "null")
            novel.chapter_count = to!int( result[9]);
        return novel;
    }

    private Chapter getChapter(Row result) {
        Chapter chapter = new Chapter();
        chapter.id = to!int( result[0]);
        chapter.title = result[1];
        chapter.url = result[2];
        chapter.position = to!int( result[3]);
        chapter.text = result[4];
        chapter.novel_id = to!int( result[5]);
        return chapter;
    }

    Chapter getChapter(string url)
    {
        auto chapter_table = ChapterTable();
        Chapter chapter = null;
        foreach (result; db.query( chapter_table.table.select().where( chapter_table.url.eq( url)).asSQL())) {
            chapter = getChapter( result);
        }
        return chapter;
    }

    Novel[] getNovels()
    {
        Novel[] novels;
        auto novel_table = NovelTable();
        auto sql = novel_table.table.select().asSQL();
        Novel novel;
        foreach (result; db.query( sql)) {
            novel = getNovel( result);
            novels ~= novel;
            novel = null;
        }
        return novels;
    }

    int insertNovel(Novel novel) {
        if (novel.title.empty() || novel.url.empty()) {
            writeln( "Novel not inserted because title or url is empty " ~ to!string( novel));
            return -1;
        }
        auto novel_table = NovelTable().table;
        void s (Setters it) {
            auto table = NovelTable();
            const auto cachedNovel = getNovel( novel.url);
            if (cachedNovel !is null) {
                it[table.id] = cachedNovel.id;
                if (novel.author.empty()) {
                    it[table.author] = cachedNovel.author;
                }
                if (novel.aliases.empty()) {
                    it[table.aliases] = cachedNovel.aliases;
                }
                if (novel.summary.empty()) {
                    it[table.summary] = cachedNovel.summary;
                }
                if (novel.genres.empty()) {
                    it[table.genres] = cachedNovel.genres;
                }
                //if (!novel.type.empty()) {
                //it[table.type] = novel.type;
                //}
                if (novel.status == -1) {
                    it[table.status] = cachedNovel.status;
                }
                if (novel.chapter_count == 0) {
                    it[table.chapter_count] = cachedNovel.chapter_count;
                }
            }
            if (!novel.title.empty()) {
                it[table.title] = novel.title;
            }
            if (!novel.url.empty()) {
                it[table.url] = novel.url;
            }
            if (!novel.cover_url.empty()) {
                it[table.cover_url] = novel.cover_url;
            }
            if (!novel.author.empty()) {
                it[table.author] = novel.author;
            }
            if (!novel.aliases.empty()) {
                it[table.aliases] = novel.aliases;
            }
            if (!novel.summary.empty()) {
                it[table.summary] = novel.summary;
            }
            if (!novel.genres.empty()) {
                it[table.genres] = novel.genres;
            }
            //if (!novel.type.empty()) {
                //it[table.type] = novel.type;
            //}
            if (novel.status != -1) {
                it[table.status] = novel.status;
            }
            if (novel.chapter_count != 0) {
                it[table.chapter_count] = novel.chapter_count;
            }
        }
        auto sql = novel_table.insertOrReplace( &s).asSQL();
        //writeln(`Insert SQL: ` ~ sql);
        db.query( sql);
        if (auto cached_novel = getNovel( novel.url)) {
            return cached_novel.id;
        } else {
            return -1;
        }
    }

    Chapter getChapter(int id)
    {
        auto chapter_table = ChapterTable();
        Chapter chapter = null;
        foreach (result; db.query( chapter_table.table.select().where( chapter_table.id.eq( id)).asSQL())) {
            chapter = getChapter( result);
        }
        return chapter;
    }

    int insertChapter(Chapter chapter)
    {
        auto chapter_table = ChapterTable().table;
        void s (Setters it) {
            import std.array: empty;
            auto table = ChapterTable();
            const auto cachedChapter = getChapter( chapter.url);
            if (cachedChapter !is null) {
                it[table.id] = cachedChapter.id;
                it[table.novel_id] = cachedChapter.novel_id;
                if (chapter.text.empty() && !cachedChapter.text.empty())
                    it[table.text] = cachedChapter.text;
            }
            if (!chapter.title.empty()) {
                it[table.title] = chapter.title;
            }
            if (!chapter.url.empty()) {
                it[table.url] = chapter.url;
            }
            if (!chapter.text.empty()) {
                it[table.text] = chapter.text;
            }
            if (!chapter.novel_id != -1) {
                it[table.novel_id] = chapter.novel_id;
            }
            if (chapter.position != -1) {
                it[table.position] = chapter.position;
            }
        }
        auto sql = chapter_table.insertOrReplace( &s).asSQL();
        //writeln(sql);
        db.query( sql);
        if (auto cached_chapter = getChapter( chapter.url)) {
            return cached_chapter.id;
        } else {
            return -1;
        }
    }

    private string insertChapterSQL(Chapter chapter)
    {
        auto chapter_table = ChapterTable().table;
        void s (Setters it) {
            import std.array: empty;
            auto table = ChapterTable();
            const auto cachedChapter = getChapter( chapter.url);
            if (cachedChapter !is null) {
                it[table.id] = cachedChapter.id;
                it[table.novel_id] = cachedChapter.novel_id;
            }
            if (!chapter.title.empty()) {
                it[table.title] = chapter.title;
            }
            if (!chapter.url.empty()) {
                it[table.url] = chapter.url;
            }
            if (!chapter.text.empty()) {
                it[table.text] = chapter.text;
            }
            if (!chapter.novel_id != -1) {
                it[table.novel_id] = chapter.novel_id;
            }
            if (chapter.position != -1) {
                it[table.position] = chapter.position;
            }
        }
        return chapter_table.insertOrReplace( &s).asSQL();
    }

    void insertChapters(Chapter[] chapters) {
        TransactionStatement transaction = new TransactionStatement();
        foreach (chapter; chapters) {
            auto sql = insertChapterSQL(chapter);
            transaction.add( sql);
        }
        auto sql = transaction.asSQL();
        db.startTransaction();
        db.query( sql);
        //db.
    }

    Chapter[] getChapters(int novel_id)
    {
        auto chapter_table = ChapterTable();
        auto sql = chapter_table.table.select().where( chapter_table.novel_id.eq( novel_id)).asSQL();
        //writeln( sql);
        Chapter[] chapters;
        foreach (result; db.query( sql)) {
            chapters ~= getChapter( result);
        }
        return chapters;
    }

    Chapter[] getChaptersMissingText()
    {
        auto chapter_table = ChapterTable();
        auto sql = chapter_table.table.select().where(chapter_table.text.isNull()).asSQL();
        writeln( sql);
        Chapter[] chapters;
        foreach (result; db.query( sql)) {
            chapters ~= getChapter( result);
        }
        return chapters;
    }

    Chapter[] getChaptersSimple(int novel_id, int limit = 0, int offset = 0)
    {
        auto chapter_table = ChapterTable();
        auto sql = chapter_table.table
        .select(chapter_table.id, chapter_table.title, chapter_table.url, chapter_table.position, chapter_table.novel_id)
        .where( chapter_table.novel_id.eq( novel_id))
        .limitOffset(limit, offset)
        .asSQL();
        //writeln( sql);
        Chapter[] chapters;
        foreach (result; db.query( sql)) {
            Chapter chapter = new Chapter();
            chapter.id = to!int( result[0]);
            chapter.title = result[1];
            chapter.url = result[2];
            chapter.position = to!int( result[3]);
            chapter.novel_id = to!int( result[4]);
            chapters ~= chapter;
        }
        return chapters;
    }

    int getChapterCount(int novel_id)
    {
        auto chapter_table = ChapterTable();
        auto sql = chapter_table.table
        .count()
        .where( chapter_table.novel_id.eq( novel_id))
        .asSQL();
        foreach (result; db.query( sql)) {
            return to!int( result[0]);
        }
        return -1;
    }

    /// Function to map the database row to a User object.
    private User getUser(Row result) {
        User user = new User();
        user.id = to!int( result[0]);
        user.username = result[1];
        user.password_hash = result[2];
        user.email = result[3];
        user.last_ip = result[4];
        user.type = to!int(result[5]);
        return user;
    }

    override User getUser(string username) {
        User user = null;
        auto user_table = UserTable();
        foreach (result; db.query( user_table.table.select().where( user_table.username.eq( username)).asSQL())) {
            user = getUser( result);
        }
        return user;
    }

    override int insertUser(User user) {
        auto user_table = UserTable().table;
        void s (Setters it) {
            auto table = UserTable();
            if (!user.username.empty()) {
                it[table.username] = user.username;
            }
            if (!user.password_hash.empty()) {
                it[table.password_hash] = user.password_hash;
            }
            if (!user.email.empty()) {
                it[table.email] = user.email;
            }
            if (!user.last_ip.empty()) {
                it[table.last_ip] = user.last_ip;
            }
            it[table.type] = 0;
        }
        string sql = user_table.insertOrReplace( &s).asSQL();
        db.query( sql);
        if (auto db_user = getUser(user.username)) {
            return db_user.id;
        } else {
            return -1;
        }
    }

    /// Insert a read history record into the database
    int insertReadHistory(ReadHistory readhistory) {
        auto read_history = ReadHistoryTable().table;
        void s (Setters it) {
            auto table = ReadHistoryTable();
            const ReadHistory cached = getReadHistory(readhistory.user_id, readhistory.novel_id);
            if (cached !is null) {
                it[table.id] = cached.id;
            }
            it[table.user_id] = readhistory.user_id;
            it[table.novel_id] = readhistory.novel_id;
            it[table.chapter_id] = readhistory.chapter_id;
            it[table.last_read_date] = db.sysTimeToValue(Clock.currTime());
        }
        string sql = read_history.insertOrReplace( &s).asSQL();
        db.query( sql);
        writeln(`Insert Read History` ~readhistory.toString);
        if (auto db_read_history = getReadHistory(readhistory.user_id, readhistory.novel_id)) {
            return db_read_history.id;
        } else {
            return -1;
        }
    }

    private ReadHistory getReadHistory(Row result) {
        ReadHistory read_history = new ReadHistory();
        read_history.id = to!int( result[0]);
        read_history.user_id = to!int(result[1]);
        read_history.novel_id = to!int(result[2]);
        read_history.chapter_id = to!int( result[3]);
        read_history.last_read_date = result[4];
        return read_history;
    }
    
    override ReadHistory getReadHistory(int id) {
        auto read_history_table = ReadHistoryTable();
        ReadHistory read_history = null;
        foreach (result; db.query( read_history_table.table.select().where( read_history_table.id.eq( id)).limitOffset(1).asSQL())) {
            read_history = getReadHistory( result);
        }
        return read_history;
    }

    override ReadHistory getReadHistory(int user_id, int novel_id) {
        auto read_history_table = ReadHistoryTable();
        ReadHistory read_history = null;
        foreach (result; db.query( read_history_table.table.select()
        .where( read_history_table.user_id.eq( user_id).and(read_history_table.novel_id.eq(novel_id)))
        .asSQL())) {
            read_history = getReadHistory( result);
        }
        return read_history;
    }
    override ReadHistory[] getUserHistory(int user_id) {
        auto read_history_table = ReadHistoryTable();
        ReadHistory read_history = null;
        ReadHistory[] history;
        foreach (result; db.query( read_history_table.table.select().where( read_history_table.user_id.eq( user_id)).asSQL())) {
            read_history = getReadHistory( result);
            history ~= read_history;
            read_history = null;
        }
        return history;
    }
}
