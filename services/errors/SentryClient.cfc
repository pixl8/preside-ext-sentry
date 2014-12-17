component output=false {

// CONSTRUCTOR
	public any function init( required string apiKey, string sentryProtocolVersion=5 ) output=false {
		_setCredentials( arguments.apiKey );
		_setProtocolVersion( arguments.sentryProtocolVersion );

		return this;
	}

// PUBLIC API METHODS
	public void function captureException( required struct expection, struct tags={}, struct extraInfo={} ) output=false {
		var e           = arguments.exception;
		var errorType   = ( e.type ?: "Unknown type" ) & " error";
		var message     = e.message ?: "";
		var detail      = e.detail  ?: "";
		var diagnostics = e.diagnostics  ?: "";
		var fullMessage = Trim( ListAppend( ListAppend( message, detail, " " ), diagnostics, " " ) );
		var packet      = {
			  message = "#errorType#: " & fullMessage
			, level   = "error"
			, culprit = e.tagContext[1].template ?: "unknown"
			, extra   = arguments.extraInfo
			, tags    = arguments.tags
		};

		packet.extra[ "Java Stacktrace" ] = ListToArray( e.stackTrace ?: "", Chr( 10 ) );
		packet.exception = {
			  type       =  errorType
			, value      =  fullMessage
			, stacktrace =  { frames=_convertTagContext( e.tagContext ?: [] ) }
		};
	}


// PRIVATE HELPERS
	private void function _setCredentials( required string apiKey ) output=false {
		var regex = "^(https?://)((.*?):(.*?)@)(.*?)/([1-9][0-9]*)$";

		_setEndpoint( ReReplaceNoCase( arguments.apiKey, regex, "\1\5" ) );
		_setPublicKey( ReReplaceNoCase( arguments.apiKey, regex, "\3" ) );
		_setPrivateKey( ReReplaceNoCase( arguments.apiKey, regex, "\4" ) );
		_setProjectId( ReReplaceNoCase( arguments.apiKey, regex, "\6" ) );
	}

	private array function _convertTagContext( required array tagContext ) output=false {
		var frames = [];

		for( var frame in arguments.tagContext ) {
			frames.prepend({
				  filename     = frame.template ?: ""
				, lineno       = Val( frame.line ?: "" )
				, colno        = Val( frame.column ?: "" )
				, abs_path     = ExpandPath( frame.template ?: "/" )
				, context_line = ""
				, pre_context  = []
				, post_context = []
			});

			( frame.codePrintPlain ?: "" ).listToArray( Chr(10) ).each( function( src ){
				var lineNo = Val( src );
				if ( lineNo < Val( frame.line ?: "" ) ) {
					frames[1].pre_context.append( src );
				} elseif ( lineNo > Val( frame.line ?: "" ) ) {
					frames[1].post_context.append( src );
				} else {
					frames[1].context_line = src;
				}
			} );
		}

		return frames;
	}

	private void function _apiCall( required struct packet ) output=false {
		var timeVars        = _getTimeVars();
		var httpRequestData = getHTTPRequestData();

		packet.event_id    = LCase( Replace( CreateUUId(), "-", "", "all" ) );
		packet.timestamp   = timeVars.timeStamp;
		packet.logger      = "raven-presidecms";
		packet.project     = _getProjectId();
		packet.server_name = cgi.server_name ?: "unknown";
		packet.request     = {
			  url          = // TODO
			, data         = FORM
			, cookies      = COOKIE
			, env          = CGI
			, method       = CGI.REQUEST_METHOD
			, query_string = CGI.QUERY_STRING
			, headers      = httpRequestData.headers ?: {}
		};

		var jsonPacket = SerializeJson( packet );
		var signature  = _generateSignature( timeVars.time, jsonPacket );
		var authHeader = "Sentry sentry_version=#_getProtocolVersion()#, sentry_signature=#signiture#, sentry_timestamp=#timeVars.time#, sentry_key=#_getPublicKey()#, sentry_client=raven-presidecms/1.0.0";

		http url=_getEndpoint() method="POST" timeout=10 {
			httpparam type="header" value=authHeader name="X-Sentry-Auth";
			httpparam type="body"   value=jsonPacket;
		}
	}

	private struct function _getTimeVars() output=false {
		var timeVars = {};

		timeVars.utcNowTime = DateConvert( "Local2utc", Now() );
		timeVars.time       = DateDiff( "s", "January 1 1970 00:00", timeVars.utcNowTime );
		timeVars.timeStamp  = Dateformat( timeVars.utcNowTime, "yyyy-mm-dd" ) & "T" & TimeFormat( timeVars.utcNowTime, "HH:mm:ss" );

		return timeVars;
	}

	private string function _generateSignature( required string time, required string json ) output=false {
		var messageToSign = ListAppend( arguments.time, arguments.json, " " );
		var jMsg = JavaCast( "string", messageToSign ).getBytes( "iso-8859-1" );
		var jKey = JavaCast( "string", _getPrivateKey() ).getBytes( "iso-8859-1" );
		var key  = CreateObject( "java", "javax.crypto.spec.SecretKeySpec" ).init( jKey, "HmacSHA1" );
		var mac  = CreateObject( "java", "javax.crypto.Mac" ).getInstance( key.getAlgorithm() ).init( key );

		mac.update( jMsg );

		return LCase( BinaryEncode( mac.doFinal(), 'hex' ) );
	}

// GETTERS AND SETTERS
	private string function _getEndpoint() output=false {
		return _endpoint;
	}
	private void function _setEndpoint( required string endpoint ) output=false {
		_endpoint = arguments.endpoint;
	}

	private string function _getPublicKey() output=false {
		return _publicKey;
	}
	private void function _setPublicKey( required string publicKey ) output=false {
		_publicKey = arguments.publicKey;
	}

	private string function _getPrivateKey() output=false {
		return _privateKey;
	}
	private void function _setPrivateKey( required string privateKey ) output=false {
		_privateKey = arguments.privateKey;
	}

	private string function _getProjectId() output=false {
		return _projectId;
	}
	private void function _setProjectId( required string projectId ) output=false {
		_projectId = arguments.projectId;
	}

	private any function _getProtocolVersion() output=false {
		return _protocolVersion;
	}
	private void function _setProtocolVersion( required any protocolVersion ) output=false {
		_protocolVersion = arguments.protocolVersion;
	}
}