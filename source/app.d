import vibe.d;
import std.regex;
import std.stdio;
import std.random : uniform;
import vibe.stream.operations : readAllUTF8;
import std.container.slist;

import std.functional : memoize;
import std.conv : to;
import std.process : environment;
import std.array : split;

enum PRE_REGEX = ctRegex!("<pre>(.*)(?!</pre>)", "gmi");
string[] people;


/**
 * Fetch a single random quote from the specified url
 */
string[] getQuotesFor(const string url) {
	auto response = requestHTTP(url);

	auto b = response.bodyReader.readAllUTF8();

	string[] quotes;


	foreach(c; matchAll(b, PRE_REGEX)) {
		quotes ~= c[1];
	}

	return quotes;
}

alias fastGetQuotesFor = memoize!getQuotesFor;

/**
 * Read .rcpeople and return them.
 */
string[] getPeople() {
	return environment["PEOPLE"].split(',');
}


void hello(HTTPServerRequest req, HTTPServerResponse res) {
	if(people.length == 0) {
		people = getPeople();
	}

	auto author = people[uniform(0, people.length)];
	auto quotes = fastGetQuotesFor("http://wiki.ceri.se/index.php?title=" ~ author);

	auto quote = quotes.length > 0 ? quotes[uniform(0, quotes.length)] : "Nothing";

	res.render!("index.dt", quote, author);
}

shared static this()
{
	auto settings = new HTTPServerSettings;
	settings.port = 3000;
	settings.bindAddresses = ["::1", "127.0.0.1"];

	auto router = new URLRouter;
	router.get("/", &hello)
	      .get("*", serveStaticFiles("./public/"));


	listenHTTP(settings, router);

	logInfo("Please open http://127.0.0.1:3000/ in your browser.");
}

