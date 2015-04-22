import vibe.d;
import std.regex;
import std.stdio;
import std.random : uniform;
import vibe.stream.operations : readAllUTF8;
import std.container.slist;

import std.functional : memoize;
import std.conv : to;
import std.process : environment;
import std.array : split, replace;

enum PRE_REGEX = ctRegex!("<pre>(.+?)</pre>", "s");
enum LI_REGEX = ctRegex!("<li>(.+?)</li>", "s");
string[] people;

struct quote_response {
	string quote;
	string author;
}

string[] getMatching(R, RegEx)(const R url, RegEx r) {
	auto response = requestHTTP(url);

	auto b = response.bodyReader.readAllUTF8();

	string[] quotes;


	foreach(c; matchAll(b, r)) {
		quotes ~= c[1].replace("\n", "<br>");
	}

	return quotes;
}

string[] getQuotesFor(const string url) {
	return getMatching(url, PRE_REGEX);
}

string[] getTidbitsFor(const string url) {
	return getMatching(url, LI_REGEX);
}

alias fastGetQuotesFor = memoize!getQuotesFor;
alias fastGetTidbitsFor = memoize!getTidbitsFor;

/**
 * Read .rcpeople and return them.
 */
string[] getPeople() {
	return environment["PEOPLE"].replace("\\","").split(",");
}

quote_response _pick_one(string[] function(const(immutable(char)[])) fetch_function) {
	if(people.length == 0) {
		people = getPeople();
	}

	quote_response response;

	response.author = people[uniform(0, people.length)];
	auto quotes = fetch_function("http://wiki.ceri.se/index.php?title=" ~ response.author);

	response.quote = quotes.length > 0 ? quotes[uniform(0, quotes.length)] : "Nothing";

	return response;
}

void quote_api(HTTPServerRequest req, HTTPServerResponse res) {
	res.writeJsonBody(_pick_one(&fastGetQuotesFor));
}

void tidbit_api(HTTPServerRequest req, HTTPServerResponse res) {
	res.writeJsonBody(_pick_one(&fastGetTidbitsFor));
}

void hello(HTTPServerRequest req, HTTPServerResponse res) {
	res.headers.addField("Cache-Control", "no-transform,public,max-age=300,s-maxage=900");
	res.render!("index.dt");
}

void tidbit(HTTPServerRequest req, HTTPServerResponse res) {
	res.headers.addField("Cache-Control", "no-transform,public,max-age=300,s-maxage=900");
	res.render!("tidbits.dt");
}


shared static this()
{
	auto settings = new HTTPServerSettings;
	settings.port = environment.get("PORT", "3000").to!ushort;
	settings.useCompressionIfPossible = true;
	//settings.bindAddresses = ["::1", "127.0.0.1"];

	auto router = new URLRouter;
	router.get("/", &hello)
		  .get("/tidbit", &tidbit)
		  .get("/api/quote", &quote_api)
		  .get("/api/tidbit", &tidbit_api)
	      .get("*", serveStaticFiles("./public/"));

	listenHTTP(settings, router);
}

