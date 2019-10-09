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

-- When invoked during a request, captures the Origin header if present
-- and stores it in a private variable.
function cors_request(txn)
  local headers = txn.http:req_get_headers()
  local origin = headers["origin"]

  if origin ~= nil then
    core.Debug("CORS: Got 'Origin' header: " .. headers["origin"][0])
    txn:set_priv(headers["origin"][0])
  end
end

-- Add headers for CORS preflight request
function preflight_request(txn, method, allowed_methods)
  if method == "OPTIONS" then
    core.Debug("CORS: preflight request OPTIONS")
    txn.http:res_add_header("Access-Control-Allow-Methods", allowed_methods)
    txn.http:res_add_header("Access-Control-Allow-Credentials", "true")
    txn.http:res_add_header("Access-Control-Max-Age", 600)
  end
end

-- When invoked during a response, sets CORS headers so that the browser
-- can read the response from permitted domains.
-- txn: The current transaction object that gives access to response properties.
-- allowed_methods: Comma-delimited list of allowed HTTP methods. (e.g. GET,POST,PUT,DELETE)
-- allowed_origins: Comma-delimited list of allowed origins. (e.g. localhost,localhost:8080,test.com)
function cors_response(txn, allowed_methods, allowed_origins)
  local method = txn.sf:method()
  local origin = txn:get_priv()

  -- Always vary on the Origin
  txn.http:res_add_header("Vary", "Accept-Encoding,Origin")

  -- Bail if client did not send an Origin
  if origin == nil or origin == '' then
    return
  end

  local allowed_origins = core.tokenize(allowed_origins, ",")

  if contains(allowed_origins, "*") then
    core.Debug("CORS: " .. "* allowed")
    txn.http:res_add_header("Access-Control-Allow-Origin", "*")
    preflight_request(txn, method, allowed_methods)
  elseif contains(allowed_origins, origin:match("//([^/]+)")) then
    core.Debug("CORS: " .. origin .. " allowed")
    txn.http:res_add_header("Access-Control-Allow-Origin", origin)
    preflight_request(txn, method, allowed_methods)
  else
    core.Debug("CORS: " .. origin .. " not allowed")
  end
end

-- Register the actions with HAProxy
core.register_action("cors", {"http-req"}, cors_request, 0)
core.register_action("cors", {"http-res"}, cors_response, 2)