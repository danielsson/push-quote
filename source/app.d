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
string[] people;

struct quote_response {
	string quote;
	string author;
}


/**
 * Fetch a single random quote from the specified url
 */
string[] getQuotesFor(const string url) {
	auto response = requestHTTP(url);

	auto b = response.bodyReader.readAllUTF8();

	string[] quotes;


	foreach(c; matchAll(b, PRE_REGEX)) {
		quotes ~= c[1].replace("\n", "<br>");
	}

	return quotes;
}

alias fastGetQuotesFor = memoize!getQuotesFor;

/**
 * Read .rcpeople and return them.
 */
string[] getPeople() {
	return environment["PEOPLE"].replace("\\","").split(",");
}

void quote(HTTPServerRequest req, HTTPServerResponse res) {
	if(people.length == 0) {
		people = getPeople();
	}

	quote_response response;

	response.author = people[uniform(0, people.length)];
	auto quotes = fastGetQuotesFor("http://wiki.ceri.se/index.php?title=" ~ response.author);

	response.quote = quotes.length > 0 ? quotes[uniform(0, quotes.length)] : "Nothing";

	res.writeJsonBody(response);
}

void hello(HTTPServerRequest req, HTTPServerResponse res) {
	res.render!("index.dt");
}

shared static this()
{
	auto settings = new HTTPServerSettings;
	settings.port = environment.get("PORT", "3000").to!ushort;
	//settings.bindAddresses = ["::1", "127.0.0.1"];

	auto router = new URLRouter;
	router.get("/", &hello)
		  .get("/api/quote", &quote)
	      .get("*", serveStaticFiles("./public/"));


	listenHTTP(settings, router);

	logInfo("Please open http://127.0.0.1:????/ in your browser.");
}

