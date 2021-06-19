module novelreader.model;
import std.conv;

///Novel Class
class Novel
{
    int id; /// Unique ID
    string title; /// Novel Title
    string url; /// Novel Url
    string cover_url; /// Novel Cover Url
    string author = ""; /// Novel Author
    string aliases= ""; /// Novel Aliases
    string summary = ""; /// Novel Summary
    string genres = ""; /// Associated Genres
    string type = ""; /// Novel Type
    int status = 0; /// Novel Status

    int chapter_count = 0; /// Novel Chapter Count

    Chapter[] chapters; /// Chapters Associated with Novel
    override string toString() {
        return title ~" " ~ url ~ " " ~ cover_url ~ " " ~ author ~ " " ~ aliases ~ " "  ~ summary ~ " " ~ genres ~ " " ~ type ~ " " ~ to!string(status);
    }
}

///Chapter Class
class Chapter {
    int id; /// Unique ID
    string title; /// Chapter Title
    string url; /// Chapter Url
    int position = -1; /// Chapter Position
    string text = ""; /// Chapter Text
    int novel_id = -1; /// Associated Novel ID
    override string toString() {
        return title ~" " ~ url ~ " " ~ text ~ " " ~ to!string(position) ~ " " ~ to!string(novel_id) ~ " ";
    }
}

///User Class
class User {
    int id; /// User ID
    string username; /// Username
    string password_salt; /// Password Salt
    string password_hash; /// Password Hash
    string email; /// Email
    string last_ip; /// Last IP
}

///Read History Class
class ReadHistory {
    int id; /// Unique ID for ReadHistory
    int user_id; /// User ID
    int novel_id; /// Novel ID
    int chapter_id; /// Last Chapter Read ID
    string last_read_date; /// Last Read Date

    override string toString() {
        return to!string(user_id) ~" " ~ to!string(novel_id) ~ " " ~ to!string(chapter_id);
    }

    Novel novel = null;
    Chapter chapter = null;
}