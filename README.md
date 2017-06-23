# Sentry Integration for Preside

## Overview

This extension provides integration with [Sentry](https://sentry.io/) for the Preside platform.

## Usage

Once installed (see below), you will need to configure your Sentry API key for your application. This can be achieved a number of ways:

* Injecting a configuration variable, `SENTRY_API_KEY` (recommended). This can be achieved with a regular system environment variable named `PRESIDE_SENTRY_API_KEY`, or by adding a `SENTRY_API_KEY` entry to the `/application/config/.injectedConfiguration` json file
* Setting an application variable `application.SENTRY_API_KEY={yourkey}`

## Installation

Install the extension to your application via either of the methods detailed below (Git submodule / CommandBox) and then enable the extension by opening up the Preside developer console and entering:

```
extension enable preside-ext-mailgun
reload all
```

### CommandBox (box.json) method

From the root of your application, type the following command:

```
box install preside-ext-sentry
```

### Git Submodule method

From the root of your application, type the following command:

```
git submodule add https://github.com/pixl8/preside-ext-sentry.git application/extensions/preside-ext-sentry
```


