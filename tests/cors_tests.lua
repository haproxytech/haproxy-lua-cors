luaunit = require('luaunit')

-- stub the 'core' global variable that HAProxy creates
core = {}
core.register_action = function()end
core.Debug = function(s)end

cors = require('cors')

-- tests...

function test_wildcard_origin_allowed_when_contains_wildcard_returns_wildcard()
  local allowed = {"*"}
  local result = cors.wildcard_origin_allowed(allowed)
  luaunit.assertEquals(result, "*")
end

function test_wildcard_origin_allowed_when_does_not_contain_wildcard_returns_nil()
  local allowed = {"testcom", "localhost"}
  local result = cors.wildcard_origin_allowed(allowed)
  luaunit.assertNil(result)
end

function test_trim_removes_leading_and_trailing_whitespace()
  local result = cors.trim("  test  ")
  luaunit.assertEquals(result, "test")
end

function test_specifies_scheme_when_scheme_given_returns_true()
  local result = cors.specifies_scheme("http://localhost")
  luaunit.assertTrue(result)
end

function test_specifies_scheme_when_scheme_not_given_returns_false()
  local result = cors.specifies_scheme("localhost")
  luaunit.assertFalse(result)
end

function test_specifies_scheme_when_generic_scheme_given_returns_false()
  local result = cors.specifies_scheme("//localhost")
  luaunit.assertFalse(result)
end

function test_specifies_generic_scheme_when_any_scheme_returns_true()
  local result = cors.specifies_generic_scheme("//localhost")
  luaunit.assertTrue(result)
end

function test_specifies_generic_scheme_when_scheme_returns_false()
  local result = cors.specifies_generic_scheme("http://localhost")
  luaunit.assertFalse(result)
end

function test_begins_with_dot_when_begins_with_dot_returns_true()
  local result = cors.begins_with_dot(".test.com")
  luaunit.assertTrue(result)
end

function test_begins_with_dot_when_does_not_begin_with_dot_returns_false()
  local result = cors.begins_with_dot("test.com")
  luaunit.assertFalse(result)
end

function test_build_pattern_1()
  local result = cors.build_pattern("localhost")
  luaunit.assertEquals(result, "//localhost$")
end

function test_build_pattern_2()
  local result = cors.build_pattern("https://localhost")
  luaunit.assertEquals(result, "https://localhost$")
end

function test_build_pattern_3()
  local result = cors.build_pattern("http://localhost:8080")
  luaunit.assertEquals(result, "http://localhost:8080$")
end

function test_build_pattern_4()
  local result = cors.build_pattern("//localhost:8080")
  luaunit.assertEquals(result, "//localhost:8080$")
end

function test_build_pattern_5()
  local result = cors.build_pattern(".test.com")
  luaunit.assertEquals(result, "%.test%.com$")
end

function test_build_pattern_6()
  local result = cors.build_pattern(".test.com:8080")
  luaunit.assertEquals(result, "%.test%.com:8080$")
end

function test_get_allowed_origin_case_1()
  local result = cors.get_allowed_origin("http://test.com", {"http://test.com"})
  luaunit.assertEquals(result, "http://test.com")
end

function test_get_allowed_origin_case_2()
  local result = cors.get_allowed_origin("http://test.com:8080", {"http://test.com:8080"})
  luaunit.assertEquals(result, "http://test.com:8080")
end

function test_get_allowed_origin_case_3()
  local result = cors.get_allowed_origin("http://localhost", {"localhost"})
  luaunit.assertEquals(result, "http://localhost")
end

function test_get_allowed_origin_case_4()
  local result = cors.get_allowed_origin("http://sub.test.com", {".test.com"})
  luaunit.assertEquals(result, "http://sub.test.com")
end

function test_get_allowed_origin_case_5()
  local result = cors.get_allowed_origin("https://sub.test.com", {".test.com"})
  luaunit.assertEquals(result, "https://sub.test.com")
end

function test_get_allowed_origin_case_6()
  local result = cors.get_allowed_origin("https://localhost", {"//localhost"})
  luaunit.assertEquals(result, "https://localhost")
end

function test_get_allowed_origin_case_7()
  local result = cors.get_allowed_origin("https://sub.test.com:8080", {".test.com:8080"})
  luaunit.assertEquals(result, "https://sub.test.com:8080")
end

function test_get_allowed_origin_case_8()
  local result = cors.get_allowed_origin("https://test.com", {".test.com"})
  luaunit.assertEquals(result, nil)
end

function test_get_allowed_origin_case_9()
  local result = cors.get_allowed_origin("https://test.com", {"localhost"})
  luaunit.assertEquals(result, nil)
end

function test_get_allowed_origin_case_10()
  local result = cors.get_allowed_origin("https://sub.test.com", {"test.com"})
  luaunit.assertEquals(result, nil)
end

function test_get_allowed_origin_case_11()
  local result = cors.get_allowed_origin("https://test.com", {"localhost", "*"})
  luaunit.assertEquals(result, "*")
end

-- this line must go at the end
os.exit(luaunit.LuaUnit.run())