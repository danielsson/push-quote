import std.regex;
import std.stdio;
import std.random : uniform;
import std.functional : memoize;
import std.conv : to;
import std.process : environment;
import std.array : split, replace;
import std.container.slist;

import vibe.stream.operations : readAllUTF8;
import vibe.d;

/** 
 * Global consts and vars.
 */
enum PRE_REGEX = ctRegex!("<pre>(.+?)</pre>", "s");
enum LI_REGEX = ctRegex!("<li>(.+?)</li>", "s");

const URL_BASE = "http://wiki.ceri.se/index.php?title=";

string[] people;

/**
 * Complete representation of a quote.
 */
struct quote_response {
	string quote;
	string author;
}

/**
 * On each call, fetch the url and return all strings that matches the 
 * regex.
 */
string[] fetchMatchingStringsFromUrl(R, RegEx)(const R url, RegEx regexp) {
	auto response = requestHTTP(url);
	auto response_str = response.bodyReader.readAllUTF8();

	string[] retval;

	foreach(c; matchAll(response_str, regexp)) {
		retval ~= c[1].replace("\n", "<br>");
	}

	return retval;
}

/**
 * Fetches all quotes from the specified url.
 */
string[] getQuotesFor(const string url) {
	return fetchMatchingStringsFromUrl(url, PRE_REGEX);
}

string[] getTidbitsFor(const string url) {
	return fetchMatchingStringsFromUrl(url, LI_REGEX);
}

alias fastGetQuotesFor = memoize!getQuotesFor;
alias fastGetTidbitsFor = memoize!getTidbitsFor;

/**
 * Read the config var
 */
string[] getPeople() {
	return environment["PEOPLE"].replace("\\","").split(",");
}

/**
 * Pick a single quote from the supplied fetch function and return
 * it in a quote_response
 */
quote_response _pick_one(string[] function(const(immutable(char)[])) fetch_function) {
	if(people.length == 0) {
		people = getPeople();
	}

	quote_response response;

	response.author = people[uniform(0, people.length)];
	auto quotes = fetch_function(URL_BASE ~ response.author);

	response.quote = quotes.length > 0 ? quotes[uniform(0, quotes.length)] : "Nothing";

	return response;
}

/*
 * API
 */
void quote_api(HTTPServerRequest req, HTTPServerResponse res) {
	res.writeJsonBody(_pick_one(&fastGetQuotesFor));
}

void tidbit_api(HTTPServerRequest req, HTTPServerResponse res) {
	res.writeJsonBody(_pick_one(&fastGetTidbitsFor));
}

/*
 * VIEWS
 */
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

