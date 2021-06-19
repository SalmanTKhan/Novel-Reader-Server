module novelreader.webservice;
import vibe.vibe;
import vibe.utils.validation;
import vibe.web.auth;
import botan.passhash.bcrypt;
import botan.rng.rng;
import std.typecons : Nullable;
import std.datetime;
import novelreader.database;
import novelreader.model;
import novelreader.parser;

// Aggregates information and roles about the currently logged in user
struct AuthInfo {
	string userName;
    bool premium;
    bool admin;

	@safe:
	bool isAdmin() { return this.admin; }
	bool isPremiumUser() { return this.premium; }
}

/++
Web Service for Vibe.d
++/
@requiresAuth
class WebService
{
    /// Novel Database
    NovelDB db;
    /// Collection of Novels
    Novel[] novels;
	/// Default constructor
    this(NovelDB _db) {
        db = _db;
        novels = db.getNovels();
    }
    
    /// All public routes wrapped into one block
	@noAuth {
        /++
        By default requests to the root path ("/")
        are routed to the index method.
        ++/
        @path("/") void getHome(scope HTTPServerRequest req, string _error = null)
		{
			if (novels.length == 0) {
				_error = "Please build the database before running the web server.";
			}
			const auto error = _error;
			if (error !is null)
				logInfo(`getHome called with error: ` ~ error);
			Nullable!AuthInfo auth;
			ReadHistory[] user_history;
			
			if (req.session && req.session.isKeySet("auth")) {
				auth = req.session.get!AuthInfo("auth");
				if (!auth.isNull) {
					const string userName = auth.get().userName;
					const user = db.getUser(userName);
					if (user !is null) {
						foreach(history; db.getUserHistory(user.id)) {
							history.novel = db.getNovel(history.novel_id);
							history.chapter = db.getChapter(history.chapter_id);
							user_history ~= history;
						}
					}
				}
			}
            render!("novels.dt", auth, novels, user_history, error);
        }

		@path("/novel/:novel_id")
        void getNovel(scope HTTPServerRequest req, int _novel_id)
        {
			getNovel(req, _novel_id, 1);
		}

        /++
        getNovel
        ++/
        @path("/novel/:novel_id/:page")
        void getNovel(scope HTTPServerRequest req, int _novel_id, int _page = 1)
        {
			Nullable!AuthInfo auth;
			if (req.session && req.session.isKeySet("auth"))
				auth = req.session.get!AuthInfo("auth");

            const Novel novel = db.getNovel(_novel_id);
            const Chapter[] chapters = db.getChaptersSimple(_novel_id, 50, 50 * (_page - 1));
            immutable page = _page;
            if (novel !is null) {
                render!("novel.dt", auth, novel, chapters, page);
            } else {
                getHome(req);
            }
        }

        /++
        getChapter
        ++/
        @path("/chapter/:chapter_id")
        void getChapter(HTTPServerRequest req, int _chapter_id)
        {
            Chapter chapter = db.getChapter(_chapter_id);
			if (chapter.text.empty()) {
				auto parser = new NovelFull; /// Currently hardcoded but should be accessed via Parser class which finds the correct parser
				chapter.text = parser.parseChapter( chapter.url);
				db.insertChapter( chapter);
			}
            if (chapter !is null) {
				const Novel novel = db.getNovel(chapter.novel_id);
            	const Chapter[] chapters = db.getChaptersSimple(chapter.novel_id);
				Nullable!AuthInfo auth;
				if (req.session && req.session.isKeySet("auth")) {
					auth = req.session.get!AuthInfo("auth");
					if (!auth.isNull) {
						const string userName = auth.get().userName;
						const user = db.getUser(userName);
						if (user !is null) {
							ReadHistory read_history = new ReadHistory();
							read_history.user_id = user.id;
							read_history.novel_id = chapter.novel_id;
							read_history.chapter_id = chapter.id;
							db.insertReadHistory(read_history);
						}
					}
				}
            	render!("chapter.dt", auth, novel, chapter, chapters);
            } else {
                getHome(req);
            }
        }

        /++
        Handle Search Queries
        ++/
        void postSearch(string query, HTTPServerRequest req)
        {
			const ReadHistory[] user_history;
			const string error = null;
			Nullable!AuthInfo auth;
			if (req.session && req.session.isKeySet("auth"))
				auth = req.session.get!AuthInfo("auth");
            const Novel[] novels = db.getNovels(query);
            render!("novels.dt", auth, novels, user_history, error);
        }

		/// Method name gets mapped to "POST /login" and two HTTP form parameters
		/// (taken from HTTPServerRequest.form or .query) are accepted.
		///
		/// The @errorDisplay attribute causes any exceptions to be passed to the
		/// _error parameter of getHome to render the error. The same happens for
		/// validation errors (ValidUsername).
		@errorDisplay!getHome
		void postLogin(ValidUsername user, string password, scope HTTPServerRequest req, scope HTTPServerResponse res)
		{
			const auto dbUser = db.getUser(user); /// Get user from database
			if (dbUser !is null) {
				enforce(checkBcrypt(password, dbUser.password_hash), "Invalid password."); /// Validate password and hashed password
				AuthInfo s = {userName: user};
				req.session = res.startSession;
				req.session.set("auth", s);
				redirect("./");
			} else {
				enforce(false, "Username or password is incorrect."); /// Error message when user not found via username
			}
		}

		/// Method name gets mapped to "POST /login" and two HTTP form parameters
		/// (taken from HTTPServerRequest.form or .query) are accepted.
		///
		/// The @errorDisplay attribute causes any exceptions to be passed to the
		/// _error parameter of getHome to render the error. The same happens for
		/// validation errors (ValidUsername).
		@errorDisplay!getHome
		void postSignup(ValidUsername user, string email, string password, string password_confirmation, scope HTTPServerRequest req, scope HTTPServerResponse res)
		{
			auto dbUser = db.getUser(user); /// Check if username exists
			if (dbUser is null) {
				const auto ip = req.clientAddress.toString().split(":")[0];
				const auto hash = generateBcrypt(password, RandomNumberGenerator.makeRng()); /// Generate a random hash from the password
				enforce(password == password_confirmation, "Passwords do not match.");
				enforce(checkBcrypt(password, hash), "Invalid password.");
				dbUser = new User();
				dbUser.username = user;
				dbUser.password_hash = hash;
				dbUser.email = email; /// Email currently unused but also can be used for additional validation
				dbUser.last_ip = ip; /// Client IP unused but can be used for additional validation like 2FA (Two factor authentication) if IP address is different
				db.insertUser(dbUser); /// Store in database
				AuthInfo s = {userName: user};
				req.session = res.startSession;
				req.session.set("auth", s);
				redirect("./");
			} else {
				enforce(false, "Username already exists.");
			}
		}
    }

    /// The authentication handler which will be called whenever auth info is needed.
	/// Its return type can be injected into the routes of the associated service.
	/// (for obvious reasons this shouldn't be a route itself)
	@noRoute
    @requiresAuth
	AuthInfo authenticate(scope HTTPServerRequest req, scope HTTPServerResponse res) @safe
	{
		if (!req.session || !req.session.isKeySet("auth"))
			throw new HTTPStatusException(HTTPStatus.forbidden, "Not authorized to perform this action!");

		return req.session.get!AuthInfo("auth");
	}


    /// Routes that require any kind of authentication
	@anyAuth {

		/// POST /logout
		void postLogout()
		{
			terminateSession();
			redirect("./");
		}

		/// GET /settings
		/// authUser is automatically injected based on the authenticate() result
		void getSettings(AuthInfo auth, string _error = null)
		{
			auto error = _error;
			//render!("settings.dt", error, auth);
		}

		/// POST /settings
		/// @errorDisplay will render errors using the getSettings method.
		/// authUser gets injected with the associated authenticate()
		@errorDisplay!getSettings
		void postSettings(bool premium, bool admin, ValidUsername user_name, AuthInfo authUser, scope HTTPServerRequest req)
		{
			AuthInfo s = authUser;
			s.userName = user_name;
			s.premium = premium;
			s.admin = admin;
			req.session.set("auth", s);
			redirect("./");
		}
	}
}