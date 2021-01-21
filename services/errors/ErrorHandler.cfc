component {

	public void function raiseError( required struct error ) {
		var sentryClient = _getSentryClient();

		if ( !IsNull( sentryClient ) ) {
			sentryClient.captureException( exception=arguments.error );
		}
	}

// private
	private any function _getSentryClient() {
		var apiKey = _getApiKey();

		if ( Len( Trim( apiKey ) ) ) {
			return new SentryClient( apiKey=apiKey, environment=_getEnvironment(), appVersion=_getAppVersion() );
		}
	}

	private string function _getApiKey() {
		return application.SENTRY_API_KEY ?: ( application.injectedConfig.SENTRY_API_KEY ?: "" );
	}

	private string function _getEnvironment() {
		return application.SENTRY_ENVIRONMENT ?: ( application.injectedConfig.SENTRY_ENVIRONMENT ?: "" );
	}

	private string function _getAppVersion() {
		return application.SENTRY_APP_VERSION ?: ( application.injectedConfig.SENTRY_APP_VERSION ?: "" );
	}

}