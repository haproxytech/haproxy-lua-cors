# HAProxy CORS Lua Library

Lua library for enabling CORS in HAProxy.

# Background

Cross-origin Request Sharing allows you to permit client-side code running within a different domain to call your services. This module extends HAProxy so that it can:

* set an *Access-Control-Allow-Methods* and *Access-Control-Max-Age* header in response to CORS preflight requests.
* set an *Access-Control-Allow-Origin* header to whitelist a domain. Note that this header should only ever return either a single domain or an asterisk (*). Otherwise, it would have been possible to hardcode all permitted domains without the need for Lua scripting.

This library checks the incoming *Origin* header, which contains the calling code's domain, and tries to match it with the list of permitted domains. If there is a match, that domain is sent back in the *Access-Control-Allow-Origin* header.

It also sets the *Vary* header to *Accept-Encoding,Origin* so that  caches do not reuse cached CORS responses for different origins.

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

In your `frontend` or `listen` section, capture the client's *Origin* request header by adding `http-request lua.cors` The first parameter is a comma-delimited list of HTTP methods that can be used. The second parameter is comma-delimited list of origins that are permitted to call your service.

```
http-request lua.cors "GET,PUT,POST" "example.com,localhost,localhost:8080"
```

Within the same section, invoke the `http-response lua.cors` action to attach CORS headers to responses from backend servers.

```
http-response lua.cors 
```

You can also whitelist all domains by setting the second parameter to an asterisk:

```
http-request lua.cors "GET,PUT,POST" "*"
```

## Preflight Requests

This module handles preflight OPTIONS requests, but it does it differently depending on if you are using HAProxy 2.2 and above. For 2.2, the module intercepts the preflight request and returns it immediately without contacting the backend server. 

For versions prior to 2.2, the module must forward the request to the backend server and then attach the CORS headers to the response as it passes back through the load balancer.

This module returns the following CORS headers for a preflight request:

* `Access-Control-Allow-Method` - set to the HTTP methods you set with `http-request lua cors` in the haproxy.cfg file
* `Access-Control-Max-Age` - set to 600

## Example

Check the *example* directory for a working demo. It uses Docker Compose to run HAProxy and a web server in containers. Go to http://localhost to test it. It demonstrates a preflight request by clicking the "PUT data" button.