# HAProxy CORS Lua Library

Lua library for enabling CORS in HAProxy.

# Background

Cross-origin Request Sharing allows you to permit client-side code running within a different domain to call your services. This module extends HAProxy so that it can:

* set an *Access-Control-Allow-Methods* header in response to CORS preflight requests.
* set an *Access-Control-Allow-Origin* header to whitelist a domain. Note that this header should only ever return either a single domain or an asterisk (*). Otherwise, it would have been possible to hardcode all permitted domains without the need for Lua scripting.

This library checks the incoming *Origin* header, which contains the calling code's domain, and tries to match it with the list of permitted domains. If there is a match, that domain is sent back in the *Access-Control-Allow-Origin* header.

## Dependencies

* HAProxy must be compiled with Lua support.

## Installation

Copy the *cors.lua* file to the server where you run HAProxy.

## Usage

Load the *cors.lua* file via the `lua-load` directive in the `global` section of your HAProxy configuration:

```
global
    log stdout local0
    lua-load /path/to/cors.lua
```

In your `frontend` or `listen` section, capture the client's *Origin* request header by adding `http-request lua.cors`:

```
http-request lua.cors
```

Within the same section, invoke the `http-response lua.cors` action. The first parameter is a comma-delimited list of HTTP methods that can be used. The second parameter is comma-delimited list of origins that are permitted to call your service. If an origin starts with a dot, all its subdomains will be allowed. 

```
http-response lua.cors "GET,PUT,POST" "example.com,.example.com,localhost,localhost:8080"
```

You can also whitelist all domains by setting the second parameter to an asterisk:

```
http-response lua.cors "GET,PUT,POST" "*"
```
