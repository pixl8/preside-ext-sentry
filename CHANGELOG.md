# Changelog

## v3.1.1

* Update build version generator

## v3.1.0

* [#9](https://github.com/pixl8/preside-ext-sentry/issues/9) Report any SQL in the error to Sentry

## v3.0.0

* #8 Enable new style API endpoint URLs
* #7 automatically tag issues with preside version and extension versions that appear in the stack trace
* #1 add ability to set an 'app_version' that sentry will use for the 'release' field in errors
* #4 put the tag context / issue trace in the correct order

## v2.0.2

* Version bump

## v2.0.1

* Do not read http request body when not used

## v2.0.0

* Add support for tagging environments
* Changing reference from _getApiKey() to local variable apiKey in _getSentryClient + removing redundant output=false parameters
* Removing redundant output=false parameters

## v1.0.1 - v1.0.3

* Build fixes and meta

## v1.0.0

Initial release
