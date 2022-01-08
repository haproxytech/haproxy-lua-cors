--
-- Cross-origin Request Sharing (CORS) implementation for HAProxy Lua host
--
-- CORS RFC:
-- https://www.w3.org/TR/cors/
--
-- Copyright (c) 2019. Nick Ramirez <nramirez@haproxy.com>
-- Copyright (c) 2019. HAProxy Technologies, LLC.

-- Loops through array to find the given string.
-- items: array of strings
-- test_str: string to search for
function contains(items, test_str)
  for _,item in pairs(items) do
    if item == test_str then
      return true
    end
  end

  return false
end

-- If the given origin is found within the allowed_origins string, it is returned. Otherwise, nil is returned.
-- domains list of allowed origins behave in new way with LUA's patterns, modification made by Piotr Pazola <piotr@webtrip.pl>
-- more about notation of patterns: https://www.lua.org/pil/20.2.html
-- origin: The value from the 'origin' request header
-- allowed_origins: Comma-delimited list of allowed origins. (e.g. localhost,localhost:8080,test.com)
-- i.e. https://mydomain.com:443 to allow only HTTPS of mydomain.com from default HTTPS source port
-- i.e. http://mydomain.com:80 to allow only HTTP of mydomain.com from default HTTP source port
-- i.e. http://mydomain.com to allow only HTTP of mydomain.com from ALL source ports
-- i.e. //mydomain.com to allow only http(s)://mydomain.com from ALL source ports
-- i.e. .mydomain.com to allow ALL subdomains of mydomain.com from ALL source ports
-- i.e. .mydomain.com:443 to allow ALL subdomains of mydomain.com from default HTTPS source port
-- i.e. //localhost to allow http(s)://localhost from ALL source ports
-- i.e. http://localhost to allow only HTTP of localhost from ALL source ports
-- i.e. https://localhost:8080 to allow only HTTPS of localhost from 8080 source port
-- i.e. ".mydomain.com:443, //mydomain.com:443, //localhost" allows all subdomains and main domain of mydomain.com only for HTTPS from default HTTPS port and allows all HTTP and HTTPS connections from ALL source port for localhost
function get_allowed_origin(origin, allowed_origins)
  if origin ~= nil then
    local allowed_origins = core.tokenize(allowed_origins, ",")

    -- wildcard CORS, return it and it is done
    if contains(allowed_origins, "*") then
      return "*"
    end

    -- remove : if there is no port at the end of origin
    if string.find(origin, ":+$") then
      origin = origin:gsub(":$", "")
    end

    local test_origin = origin
    local test_origin_port = 0

    -- set default port depends on protocol
    -- it is required to build test string which includes always port number
    if string.find(test_origin, "^https://") then
      test_origin_port = 443
    else
      test_origin_port = 80
    end

    -- if there is no port number in origin, add it to test string
    if string.find(test_origin, ":%d+$") == nil then
      test_origin = test_origin .. ":" .. test_origin_port
    end

    for index, value in ipairs(allowed_origins) do
      -- remove spaces
      value = value:gsub("%s+", "")
      -- build pattern for match: escape dots and add suffix of optional port if needed and hard sign of end of string
      value = value:gsub("%.", "%%.")
      if string.find(value, ":%d+$") == nil then
        value = value .. "[:]+[0-9]+"
      end
      value = value .. "$"

      core.Debug("Value: " .. value .. ", looking for: " .. origin)

      if test_origin:match(value) then
        core.Debug("Value: " .. value .. ", tested origin: " .. test_origin .. ", matched origin: " .. origin)
        return origin
      end
    end

  end

  return nil
end

-- Adds headers for CORS preflight request and then attaches them to the response
-- after it comes back from the server. This works with versions of HAProxy prior to 2.2.
-- The downside is that the OPTIONS request must be sent to the backend server first and can't 
-- be intercepted and returned immediately.
-- txn: The current transaction object that gives access to response properties
-- allowed_methods: Comma-delimited list of allowed HTTP methods. (e.g. GET,POST,PUT,DELETE)
-- allowed_headers: Comma-delimited list of allowed headers. (e.g. X-Header1,X-Header2)
function preflight_request_ver1(txn, allowed_methods, allowed_headers)
  core.Debug("CORS: preflight request received")
  txn.http:res_set_header("Access-Control-Allow-Methods", allowed_methods)
  txn.http:res_set_header("Access-Control-Allow-Headers", allowed_headers)
  txn.http:res_set_header("Access-Control-Max-Age", 600)
  core.Debug("CORS: attaching allowed methods to response")
end

-- Add headers for CORS preflight request and then returns a 204 response.
-- The 'reply' function used here is available in HAProxy 2.2+. It allows HAProxy to return
-- a reply without contacting the server.
-- txn: The current transaction object that gives access to response properties
-- origin: The value from the 'origin' request header
-- allowed_methods: Comma-delimited list of allowed HTTP methods. (e.g. GET,POST,PUT,DELETE)
-- allowed_origins: Comma-delimited list of allowed origins. (e.g. localhost,localhost:8080,test.com)
-- allowed_headers: Comma-delimited list of allowed headers. (e.g. X-Header1,X-Header2)
function preflight_request_ver2(txn, origin, allowed_methods, allowed_origins, allowed_headers)
  core.Debug("CORS: preflight request received")

  local reply = txn:reply()
  reply:set_status(204, "No Content")
  reply:add_header("Content-Type", "text/html")
  reply:add_header("Access-Control-Allow-Methods", allowed_methods)
  reply:add_header("Access-Control-Allow-Headers", allowed_headers)
  reply:add_header("Access-Control-Max-Age", 600)

  local allowed_origin = get_allowed_origin(origin, allowed_origins)

  if allowed_origin == nil then
    core.Debug("CORS: " .. origin .. " not allowed")
  else
    core.Debug("CORS: " .. origin .. " allowed")
    reply:add_header("Access-Control-Allow-Origin", allowed_origin)

    if allowed_origin ~= "*" then
      reply:add_header("Vary", "Accept-Encoding,Origin")
    end
  end

  core.Debug("CORS: Returning reply to preflight request")
  txn:done(reply)
end

-- When invoked during a request, captures the origin header if present and stores it in a private variable.
-- If the request is OPTIONS and it is a supported version of HAProxy, returns a preflight request reply.
-- Otherwise, the preflight request header is added to the response after it has returned from the server.
-- txn: The current transaction object that gives access to response properties
-- allowed_methods: Comma-delimited list of allowed HTTP methods. (e.g. GET,POST,PUT,DELETE)
-- allowed_origins: Comma-delimited list of allowed origins. (e.g. localhost,localhost:8080,test.com)
-- allowed_headers: Comma-delimited list of allowed headers. (e.g. X-Header1,X-Header2)
function cors_request(txn, allowed_methods, allowed_origins, allowed_headers)
  local headers = txn.http:req_get_headers()
  local transaction_data = {}
  local origin = nil
  
  if headers["origin"] ~= nil and headers["origin"][0] ~= nil then
    core.Debug("CORS: Got 'Origin' header: " .. headers["origin"][0])
    origin = headers["origin"][0]
  end

  -- Bail if client did not send an Origin
  -- for example, it may be a regular OPTIONS request that is not a CORS preflight request
  if origin == nil or origin == '' then
    return
  end
  
  transaction_data["origin"] = origin
  transaction_data["allowed_methods"] = allowed_methods
  transaction_data["allowed_origins"] = allowed_origins
  transaction_data["allowed_headers"] = allowed_headers

  txn:set_priv(transaction_data)

  local method = txn.sf:method()
  transaction_data["method"] = method

  if method == "OPTIONS" and txn.reply ~= nil then
    preflight_request_ver2(txn, origin, allowed_methods, allowed_origins, allowed_headers)
  end
end

-- When invoked during a response, sets CORS headers so that the browser can read the response from permitted domains.
-- txn: The current transaction object that gives access to response properties.
function cors_response(txn)
  local transaction_data = txn:get_priv()

  if transaction_data == nil then
    return
  end
  
  local origin = transaction_data["origin"]
  local allowed_origins = transaction_data["allowed_origins"]
  local allowed_methods = transaction_data["allowed_methods"]
  local allowed_headers = transaction_data["allowed_headers"]
  local method = transaction_data["method"]

  -- Bail if client did not send an Origin
  if origin == nil or origin == '' then
    return
  end

  local allowed_origin = get_allowed_origin(origin, allowed_origins)

  if allowed_origin == nil then
    core.Debug("CORS: " .. origin .. " not allowed")
  else
    if method == "OPTIONS" and txn.reply == nil then
      preflight_request_ver1(txn, allowed_methods, allowed_headers)
    end
    
    core.Debug("CORS: " .. origin .. " allowed")
    txn.http:res_set_header("Access-Control-Allow-Origin", allowed_origin)

    if allowed_origin ~= "*" then
      txn.http:res_add_header("Vary", "Accept-Encoding,Origin")
    end
  end
end

-- Register the actions with HAProxy
core.register_action("cors", {"http-req"}, cors_request, 3)
core.register_action("cors", {"http-res"}, cors_response, 0)
