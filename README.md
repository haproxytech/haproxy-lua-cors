# HAProxy CORS Lua Library

Lua library for enabling CORS in HAProxy.

## Background

Cross-origin Request Sharing allows you to permit client-side code running within a different domain to call your services. This module extends HAProxy so that it can:

* set an *Access-Control-Allow-Methods* header in response to a preflight request
* set an *Access-Control-Allow-Headers* header in response to a preflight request
* set an *Access-Control-Max-Age* header in response to a preflight request
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
    lua-load /path/to/cors.lua
```

In your `frontend` or `listen` section, capture the client's *Origin* request header by adding `http-request lua.cors` Its parameters are:

* The first parameter is a comma-delimited list of HTTP methods that can be used. This is used to set the *Access-Control-Allow-Methods* header.
* The second parameter is comma-delimited list of origins that are permitted to call your service. This is used to set the *Access-Control-Allow-Origin* header.
* The third parameter is a comma-delimited list of custom headers that can be used. This is used to set the *Access-Control-Allow-Headers* header.

Each of these parameters can be set to an asterisk (*) to allow all values.

Within the same `frontend` or `listen` section, add the `http-response lua.cors` action to attach CORS headers to responses from backend servers.

## Allowed origin patterns

For the list of allowed origins, you can specify patterns such as:

| pattern                       | example                  | description                                                             |
|-------------------------------|--------------------------|-------------------------------------------------------------------------|
| domain name alone             | mydomain.com             | allow any scheme (HTTP or HTTPS) for mydomain.com from ALL source ports |
| generic schema and domain     | //mydomain.com           | allow any scheme (HTTP or HTTPS) for mydomain.com from ALL source ports |
| schema and domain name        | https://mydomain.com     | allow only HTTPS of mydomain.com                                        |
| schema, domain name, and port | http://mydomain.com:8080 | allow only HTTP of mydomain.com from port 8080                          |
| dot and domain name           | .mydomain.com            | allow ALL subdomains of mydomain.com from ALL source ports              |
| dot, domain name, and port    | .mydomain.com:443        | allow ALL subdomains of mydomain.com from default HTTPS source port     |

## Examples

**Example 1: Allow specific methods, origins and headers**
```
http-request lua.cors "GET,PUT,POST" "example.com,localhost,localhost:8080" "X-Custom-Header1,X-Custom-Header2"

http-response lua.cors 
```

**Example 2: Allow all methods, origins, and headers**

```
http-request lua.cors "*" "*" "*"

http-response lua.cors 
```

## Preflight Requests

This module handles preflight OPTIONS requests, but it does it differently depending on if you are using HAProxy 2.2 and above. For 2.2, the module intercepts the preflight request and returns it immediately without contacting the backend server. 

For versions prior to 2.2, the module must forward the request to the backend server and then attach the CORS headers to the response as it passes back through the load balancer.

This module returns the following CORS headers for a preflight request:

* `Access-Control-Allow-Methods` - set to the HTTP methods you set with `http-request lua cors` in the haproxy.cfg file
* `Access-Conrol-Allow-Headers` - set to the HTTP headers you set with `http-request lua cors` in the haproxy.cfg file
* `Access-Control-Max-Age` - set to 600

## Example

Check the *example* directory for a working demo. It uses Docker Compose to run HAProxy and a web server in containers. 

1. Run the example with Docker Compose:

   ```
   docker-compose -f docker-compose.example.yml up
   ```
2. Go to http://localhost to test it. It demonstrates a preflight request by clicking the "PUT data" button.

## Tests

Run the unit tests:

1. Run the unit tests with Docker Compose:

   ```
   docker-compose -f docker-compose.tests.yml up
   ```
