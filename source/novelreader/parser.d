module novelreader.parser;
import novelreader.model;
import arsd.dom;
import std.stdio;
import std.algorithm.searching;
import std.array : replace;
import std.conv;
import std.string : strip;

/// Interface for a novel website parser
interface Parser {
    /// Parse Novels
    /// Parses novels from specified url
    Novel[] parseNovels(string url, int page);
    /// Parse Novel
    /// Parses novel and chapters from specified url
    Novel parseNovel(string url);
    /// Parse Chapter
    /// Parses text from specified chapter url
    string parseChapter(string url);
}

/// Implementation of a parser for NovelFull.com
class NovelFull: Parser {
    override Novel[] parseNovels(string url = "https://novelfull.com/index.php/most-popular?page=1", int page = 1) {
        auto document = Document.fromUrl( url.replace( "1", to!string( page)));
        auto elements = document.querySelectorAll( "div[class=row]");
        Novel[] novels;
        foreach (i, element; elements)
        {
            if (element !is null) {
                auto novel = new Novel();
                if (element.querySelector( "div[class=col-xs-7]") !is null) {
                    auto internalElement = element.querySelector( "div[class=col-xs-7]");
                    if (internalElement.querySelector( "h3[class=truyen-title]") !is null)
                        novel.title = internalElement.querySelector( "h3[class=truyen-title]").innerText().replace( "â€™", "'").strip();
                    if (internalElement.querySelector( "a") !is null)
                        novel.url = internalElement.querySelector( "a").getAttribute( "abs:href");
                    if (internalElement.querySelector( "span[class=author]") !is null)
                        novel.author = internalElement.querySelector( "span[class=author]").innerText().strip();
                }
                if (element.querySelector( "div[class=col-xs-3]") !is null) {
                    auto imageElement = element.querySelector( "div[class=col-xs-3]").querySelector( "img");
                    if (imageElement !is null) {
                        novel.cover_url = imageElement.getAttribute( "abs:src");
                    }
                }
                if (novel.title !is null)
                    novels ~= novel;
            }
        }
        return novels;
    }

    Novel parseNovel(string url) {
        auto novel = new Novel();
        auto document = Document.fromUrl( url );
        novel.url = url;
        novel.title = document.querySelector( "h3[class=title]").innerText();
        novel.cover_url = document.querySelector( "div[class=book]").querySelector( "img").getAttribute( "abs:src");
        auto elements = document.querySelector( "div[class=info]").querySelectorAll( "div");
        foreach (i, element; elements)
        {
            if (element.innerText().startsWith( "Author:")) {
                novel.author = element.innerText().replace( "Author:", "").strip();
            } else if (element.innerText().startsWith( "Alternative names:")) {
                novel.aliases = element.innerText().replace( "Alternative names:", "").strip();
            } else if (element.innerText().startsWith( "Genre:")) {
                novel.genres = element.innerText().replace( "Genre:", "").strip();
            } else if (element.innerText().startsWith( "Status:")) {
                if (element.innerText().replace( "Status:", "").strip() == "Completed") {
                    novel.status = 1;
                } else {
                    novel.status = 0;
                }
            }
        }
        novel.summary = document.querySelector( "div[class=desc-text]").querySelector( "p").innerText().strip();

        if (document.querySelector("ul[class=pagination pagination-sm]") !is null) {
            string lastPageString = document.querySelector( "ul[class=pagination pagination-sm]").querySelector( "li[class=last]").querySelector( "a").getAttribute( "data-page");
            const auto lastPage = to!int( lastPageString) + 1;
            for (int i = 1; i <= lastPage; i++) {
                novel.chapters ~= getChapters( novel.url ~ "?page=" ~ to!string( i) ~"&per-page=50");
            }
        } else {
            novel.chapters ~= getChapters( novel.url ~ "?page=" ~ to!string( 1) ~"&per-page=50");
        }
        foreach (i, chapter; novel.chapters) {
            chapter.position = to!int( i);
        }
        if (novel.chapters.length == 0) {
            throw new Exception( "No chapters found"); // Do we need to throw an exception here? Is it a graceful solution?
        }
        novel.chapter_count = to!int( novel.chapters.length);
        writeln( `Chapters loaded: ` ~ to!string( novel.chapters.length));
        return novel;
    }

    Novel parseNovel(Novel novel) {
        import std.stdio;
        import std.math: floor;
        auto document = Document.fromUrl( novel.url );
        novel.title = document.querySelector( "h3[class=title]").innerText();
        novel.cover_url = document.querySelector( "div[class=book]").querySelector( "img").getAttribute( "abs:src");
        auto elements = document.querySelector( "div[class=info]").querySelectorAll( "div");
        foreach (i, element; elements)
        {
            if (element.innerText().startsWith( "Author:"))
            {
                novel.author = element.innerText().replace( "Author:", "").strip();
            }
            else if (element.innerText().startsWith( "Alternative names:"))
            {
                novel.aliases = element.innerText().replace( "Alternative names:", "").strip();
            }
            else if (element.innerText().startsWith( "Genre:"))
                {
                    novel.genres = element.innerText().replace( "Genre:", "").strip();
                }
                else if (element.innerText().startsWith( "Status:")) {
                        if (element.innerText().replace( "Status:", "").strip() == "Completed") {
                            novel.status = 1;
                        } else {
                            novel.status = 0;
                        }
                    }
        }
        novel.summary = document.querySelector( "div[class=desc-text]").querySelector( "p").innerText().strip();

        if (document.querySelector("ul[class=pagination pagination-sm]") !is null) {
            string lastPageString = document.querySelector( "ul[class=pagination pagination-sm]").querySelector( "li[class=last]").querySelector( "a").getAttribute( "data-page");
            //writeln( `Last Page: ` ~ lastPageString);
            int currentPage = 1;
            const auto lastPage = to!int( lastPageString) + 1;
            if (novel.chapter_count > 0) {
                const double casted_count = to!double(novel.chapter_count);
                const double chapter_per_page = 50.0;
                currentPage = to!int(floor(casted_count/chapter_per_page));
            }
            for (int i = currentPage; i <= lastPage; i++) {
                novel.chapters ~= getChapters( novel.url ~ "?page=" ~ to!string( i) ~"&per-page=50");
            }
        } else {
            novel.chapters ~= getChapters( novel.url ~ "?page=" ~ to!string( 1) ~"&per-page=50");
        }
        foreach (i, chapter; novel.chapters) {
            chapter.position = to!int( i);
        }
        novel.chapter_count = to!int( novel.chapters.length);
        writeln( `Chapters loaded: ` ~ to!string( novel.chapters.length));
        return novel;
    }

    Chapter[] getChapters(string url) {
        auto document = Document.fromUrl( url );
        Chapter[] chapters;
        auto chapterElementsList = document.querySelectorAll( "ul[class=list-chapter]");
        Element[] chapterElements;
        foreach (chapterElement; chapterElementsList)
        {
            chapterElements ~= chapterElement.querySelectorAll( "li");
        }
        //writeln( `getChapters: Elements List Found`);
        foreach (i, chapterElement; chapterElements)
        {
            auto chapter = new Chapter;
            chapter.title = chapterElement.querySelector( "a").querySelector( "span").innerText().replace( "â€™", "'").strip();
            chapter.url = chapterElement.querySelector( "a").getAttribute( "abs:href");
            chapters ~= chapter;
        }
        chapterElementsList = null;
        chapterElements = null;
        return chapters;
    }

    string parseChapter(string url) {
        auto text = "";
        auto document = Document.fromUrl( url );
        foreach(element; document.querySelectorAll("script")) {
            element.removeFromTree();
        }
        foreach(element; document.querySelectorAll("ins")) {
            element.removeFromTree();
        }
        text = document.querySelector( "div[id=chapter-content]")
        .innerHTML()
        .replace(`If you find any errors ( broken links, non-standard content, etc.. ), Please let us know &lt; report chapter &gt; so we can fix it as soon as possible. </div>`, "")
        .replace(`<div align="left">`, "").replace(`<div class="ads ads-holder ads-middle text-center"></div>`, "")
        .replace(`<p>ChapterMid();</p>`, "")
        .strip();
        return text;
    }
}