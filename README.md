# Sentry Integration for Preside

## Overview

This extension provides integration with [Sentry](https://sentry.io/) for the Preside platform.

## Installation

The project is [registered on forgebox](https://forgebox.io/view/preside-ext-sentry). Using Commandbox, from the root of your application, type the following command:

```sh
box install preside-ext-sentry
```

## Usage

Once installed (see below), you will need to configure your Sentry API key for your application. This can be achieved a number of ways:

* Injecting a configuration variable, `SENTRY_API_KEY` (recommended). This can be achieved with a regular system environment variable named `PRESIDE_SENTRY_API_KEY`, or by adding a `SENTRY_API_KEY` entry to the `/application/config/.injectedConfiguration` json file
* Setting an application variable `application.SENTRY_API_KEY={yourkey}`

> As of `v3.0.0`, the extension supports the new format of Client key which does not include the secret. Old-style Client keys (those containing `public:secret`) are still supported, although the secret will not be used.

### Environments and releases

In addition, you can optionally specify an "application version" (release) and an application "environment" that Sentry can use. This way you are able to distinguish within the same Sentry project different releases and server environments, e.g. production, staging, development, ...
Note: Environments are supported as of Sentry version 9.

* Injecting a configuration variable, `SENTRY_ENVIRONMENT` (recommended). This can be achieved with a regular system environment variable named `PRESIDE_SENTRY_ENVIRONMENT`, or by adding a `SENTRY_ENVIRONMENT` entry to the `/application/config/.injectedConfiguration` json file
* Setting an application variable `application.SENTRY_ENVIRONMENT={yourenvironment}`

* Injecting a configuration variable, `SENTRY_APP_VERSION` (recommended). This can be achieved with a regular system environment variable named `PRESIDE_SENTRY_APP_VERSION`, or by adding a `SENTRY_APP_VERSION` entry to the `/application/config/.injectedConfiguration` json file
* Setting an application variable `application.SENTRY_APP_VERSION={yourenvironment}`

