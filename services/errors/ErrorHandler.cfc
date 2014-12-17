component output=false {

	public void function raiseError( required struct error ) output=false {
		var client = _getSentryClient();

		if ( !IsNull( client ) ) {
			client.captureException( arguments.error );
		}
	}

// private
	private any function _getSentryClient() output=false {
		var apiKey = _getApiKey();

		if ( Len( Trim( apiKey ) ) ) {
			return new SentryClient( _getApiKey() );
		}
	}

	private string function _getApiKey() output=false {
		return application.SENTRY_API_KEY ?: ( application.injectedConfig.SENTRY_API_KEY ?: "" );
	}

}