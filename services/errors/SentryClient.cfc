component {

// CONSTRUCTOR
	public any function init(
		  required string apiKey
		, required string environment
		, required string appVersion
		,          string sentryProtocolVersion="7"
	) {
		_setCredentials( arguments.apiKey );
		_setEnvironment( arguments.environment );
		_setAppVersion( arguments.appVersion );
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
			, tags    = StructCopy( arguments.tags )
		};

		packet.extra[ "Java Stacktrace" ] = ListToArray( e.stackTrace ?: "", Chr( 10 ) );
		packet.exception = {
			  type       =  errorType
			, value      =  fullMessage
			, stacktrace =  { frames=_convertTagContext( e.tagContext ?: [] ) }
		};

		StructAppend( packet.tags, _autoGenerateErrorTags( packet ) );

		for( var tagName in packet.tags ) {
			if ( Len( tagName ) >= 30 ) {
				packet.tags[ Left( tagName, 27 ) & "..." ] = packet.tags[ tagName ];
				StructDelete( packet.tags, tagName );
			}
		}

		_apiCall( packet );
	}


// PRIVATE HELPERS
	private void function _setCredentials( required string apiKey ) {
		var regex = "^(https?://)(.*)@(.*?)/([1-9][0-9]*)$";

		if ( reFindNoCase( regex, arguments.apiKey ) ) {
			var projectId = ReReplaceNoCase( arguments.apiKey, regex, "\4" );

			_setProjectId( projectId );
			_setEndpoint( ReReplaceNoCase( arguments.apiKey, regex, "\1\3" ) & "/api/#projectId#/store/" );
			_setPublicKey( ListFirst( ReReplaceNoCase( arguments.apiKey, regex, "\2" ), ":" ) );
		}
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
		if ( _useAppVersion() ) {
			packet.release = _getAppVersion();
		}

		var jsonPacket = SerializeJson( packet );
		var authHeader = "Sentry sentry_version=#_getProtocolVersion()#, sentry_timestamp=#timeVars.time#, sentry_key=#_getPublicKey()#, sentry_client=raven-presidecms/3.0.0";

		http url=_getEndpoint() method="POST" timeout=10 {
			httpparam type="header" value="application/json" name="Content-Type";
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

	private boolean function _useEnvironment() {
		return len( _getEnvironment() );
	}

	private boolean function _useAppVersion() {
		return len( _getAppVersion() );
	}

	private struct function _autoGenerateErrorTags( required struct packet ) {
		var presideVersion = _getPresideVersion();
		var autoTags = { "Preside Version" = presideVersion };

		if ( ReFind( "^[0-9]+\.[0-9]+\.[0-9]+", presideVersion ) ) {
			autoTags[ "Preside Major Version" ] = ReReplace( presideVersion, "^([0-9]+)\.[0-9]+\.[0-9]+.*$", "\1" );
			autoTags[ "Preside Minor Version" ] = ReReplace( presideVersion, "^([0-9]+)\.([0-9]+)\.[0-9]+.*$", "\1.\2" );
		}

		var frames = arguments.packet.exception.stacktrace.frames ?: [];
		for( var frame in frames ) {
			if ( ( frame.abs_path ?: "" ) contains "/application/extensions/" ) {
				var extension = ReReplace( frame.abs_path, "^.*/application/extensions/(.*?)/.*$", "\1" );

				StructAppend( autoTags, _getExtensionDetails( extension ) );
			}
		}

		return autoTags;
	}

	private string function _getPresideVersion() {
		if ( !StructKeyExists( variables, "_presideVersion" ) ) {
			try {
				var manifest = DeserializeJson( FileRead( ExpandPath( "/preside/version.json" ) ) );
				variables._presideVersion = Replace( manifest.version ?: "unknown", "\", "" );
			} catch( any e ) {
				variables._presideVersion = "unknown";
			}
		}

		return variables._presideVersion;

	}

	private struct function _getExtensionDetails( required string extension ) {
		variables._extensionVersionCache = variables._extensionVersionCache ?: {};

		if ( !StructKeyExists( variables._extensionVersionCache, arguments.extension ) ) {
			try {
				var manifest = DeserializeJson( FileRead( ExpandPath( "/app/extensions/#arguments.extension#/manifest.json" ) ) );
				var name = manifest.title ?: Replace( arguments.extension, "preside-ext-", "" );
				variables._extensionVersionCache[ arguments.extension ] = { "#name#" = manifest.version ?: "unknown" };
			} catch( any e ) {
				var name = Replace( arguments.extension, "preside-ext-", "" );
				variables._extensionVersionCache[ arguments.extension ] = { "#name#" = "unknown" };
			}
		}

		return variables._extensionVersionCache[ arguments.extension ];
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

	private string function _getAppVersion() {
	    return _appVersion;
	}
	private void function _setAppVersion( required string appVersion ) {
	    _appVersion = arguments.appVersion;
	}
}