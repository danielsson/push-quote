push-quote
==========

Push-quote highlights quotes and factoids from a media-wiki instance.

Building the project
--------------------
1. `git clone git@github.com:danielsson/push-quote.git`
2. `cd push-quote`
3. Install dub(https://github.com/D-Programming-Language/dub) and dependencies
4. (to run) `dub` or (to build release) `dub build --build release`

Configuration
-------------
To run properly, you must define the configuration environment variables.

To set the pages that should be scraped:
  
    export PEOPLE=PersonOneUsername,PersonTwoUsername
