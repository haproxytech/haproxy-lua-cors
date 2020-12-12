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
-- origin: The value from the 'origin' request header
-- allowed_origins: Comma-delimited list of allowed origins. (e.g. localhost,localhost:8080,test.com)
function get_allowed_origin(origin, allowed_origins)
  if origin ~= nil then
    local allowed_origins = core.tokenize(allowed_origins, ",")

    -- Strip whitespace
    for index, value in ipairs(allowed_origins) do
      allowed_origins[index] = value:gsub("%s+", "")
    end

    if contains(allowed_origins, "*") then
      return "*"
    elseif contains(allowed_origins, origin:match("//([^/]+)")) then
      return origin
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
