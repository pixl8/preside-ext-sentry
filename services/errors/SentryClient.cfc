component {

// CONSTRUCTOR
	public any function init( required string apiKey, required string environment, string sentryProtocolVersion="2.0" ) {
		_setCredentials( arguments.apiKey );
		_setEnvironment( arguments.environment );
		_setProtocolVersion( arguments.sentryProtocolVersion );

		return this;
	}

// PUBLIC API METHODS
	public void function captureException( required struct exception, struct tags={}, struct extraInfo={} ) {
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

		_apiCall( packet );
	}


// PRIVATE HELPERS
	private void function _setCredentials( required string apiKey ) {
		var regex = "^(https?://)((.*?):(.*?)@)(.*?)/([1-9][0-9]*)$";

		_setEndpoint( ReReplaceNoCase( arguments.apiKey, regex, "\1\5" ) & "/api/store/" );
		_setPublicKey( ReReplaceNoCase( arguments.apiKey, regex, "\3" ) );
		_setPrivateKey( ReReplaceNoCase( arguments.apiKey, regex, "\4" ) );
		_setProjectId( ReReplaceNoCase( arguments.apiKey, regex, "\6" ) );
	}

	private array function _convertTagContext( required array tagContext ) {
		var frames = [];

		for( var tc in arguments.tagContext ) {
			var frame = {
				  filename     = tc.template ?: ""
				, lineno       = Val( tc.line ?: "" )
				, colno        = Val( tc.column ?: "" )
				, abs_path     = ExpandPath( tc.template ?: "/" )
				, context_line = ""
				, pre_context  = []
				, post_context = []
			};

			( tc.codePrintPlain ?: "" ).listToArray( Chr(10) ).each( function( src ){
				var lineNo = Val( src );
				if ( lineNo < Val( tc.line ?: "" ) ) {
					frame.pre_context.append( src );
				} elseif ( lineNo > Val( tc.line ?: "" ) ) {
					frame.post_context.append( src );
				} else {
					frame.context_line = src;
				}
			} );

			frames.prepend( frame );
		}

		return frames;
	}

	private void function _apiCall( required struct packet ) {
		var timeVars        = _getTimeVars();

		packet.event_id    = LCase( Replace( CreateUUId(), "-", "", "all" ) );
		packet.timestamp   = timeVars.timeStamp;
		packet.logger      = "raven-presidecms";
		packet.project     = _getProjectId();
		packet.server_name = cgi.server_name ?: "unknown";
		packet.request     = _getHttpRequest();

		if ( _useEnvironment() ) {
			packet.environment = _getEnvironment();
		}

		var jsonPacket = SerializeJson( packet );
		var signature  = _generateSignature( timeVars.time, jsonPacket );
		var authHeader = "Sentry sentry_version=#_getProtocolVersion()#, sentry_signature=#signature#, sentry_timestamp=#timeVars.time#, sentry_key=#_getPublicKey()#, sentry_client=raven-presidecms/1.0.0";

		http url=_getEndpoint() method="POST" timeout=10 {
			httpparam type="header" value=authHeader name="X-Sentry-Auth";
			httpparam type="body"   value=jsonPacket;
		}
	}

	private struct function _getHttpRequest() {
		var httpRequestData = getHTTPRequestData( false );
		var rq = {
			  data         = FORM
			, cookies      = COOKIE
			, env          = CGI
			, method       = CGI.REQUEST_METHOD
			, headers      = httpRequestData.headers ?: {}
			, query_string = ""
		};
		rq.url = ListFirst( ( httpRequestData.headers['X-Original-URL'] ?: cgi.path_info ), '?' );
		if ( !Len( Trim( rq.url ) ) ) {
			rq.url = request[ "javax.servlet.forward.request_uri" ] ?: "";
			if ( !Len( Trim( rq.url ) ) ) {
				rq.url = ReReplace( ( cgi.request_url ?: "" ), "^https?://(.*?)/(.*?)(\?.*)?$", "/\2" );
			}
		}

		rq.url = ( cgi.server_name ?: "" ) & rq.url;
		rq.url = ( cgi.server_protocol contains "HTTPS" ? "https://" : "http://" ) & rq.url;

		if ( ListLen( httpRequestData.headers['X-Original-URL'] ?: "", "?" ) > 1 ) {
			rq.query_string = ListRest( httpRequestData.headers['X-Original-URL'], "?" );
		}
		if ( !Len( Trim( rq.query_string ) ) ) {
			rq.query_string = request[ "javax.servlet.forward.query_string" ] ?: ( cgi.query_string ?: "" );
		}

		return rq;
	}

	private struct function _getTimeVars() {
		var timeVars = {};

		timeVars.utcNowTime = DateConvert( "Local2utc", Now() );
		timeVars.time       = DateDiff( "s", "January 1 1970 00:00", timeVars.utcNowTime );
		timeVars.timeStamp  = Dateformat( timeVars.utcNowTime, "yyyy-mm-dd" ) & "T" & TimeFormat( timeVars.utcNowTime, "HH:mm:ss" );

		return timeVars;
	}

	private string function _generateSignature( required string time, required string json ) {
		var messageToSign = ListAppend( arguments.time, arguments.json, " " );
		var jMsg = JavaCast( "string", messageToSign ).getBytes( "iso-8859-1" );
		var jKey = JavaCast( "string", _getPrivateKey() ).getBytes( "iso-8859-1" );
		var key  = CreateObject( "java", "javax.crypto.spec.SecretKeySpec" ).init( jKey, "HmacSHA1" );
		var mac  = CreateObject( "java", "javax.crypto.Mac" ).getInstance( key.getAlgorithm() );

		mac.init( key );
		mac.update( jMsg );

		return LCase( BinaryEncode( mac.doFinal(), 'hex' ) );
	}

	private boolean function _useEnvironment() {
		return len( _getEnvironment() );
	}

// GETTERS AND SETTERS
	private string function _getEndpoint() {
		return _endpoint;
	}
	private void function _setEndpoint( required string endpoint ) {
		_endpoint = arguments.endpoint;
	}

	private string function _getPublicKey() {
		return _publicKey;
	}
	private void function _setPublicKey( required string publicKey ) {
		_publicKey = arguments.publicKey;
	}

	private string function _getPrivateKey() {
		return _privateKey;
	}
	private void function _setPrivateKey( required string privateKey ) {
		_privateKey = arguments.privateKey;
	}

	private string function _getProjectId() {
		return _projectId;
	}
	private void function _setProjectId( required string projectId ) {
		_projectId = arguments.projectId;
	}

	private any function _getProtocolVersion() {
		return _protocolVersion;
	}
	private void function _setProtocolVersion( required any protocolVersion ) {
		_protocolVersion = arguments.protocolVersion;
	}

	private any function _getEnvironment() {
		return _environment;
	}
	private void function _setEnvironment( required any environment ) {
		_environment = arguments.environment;
	}
}