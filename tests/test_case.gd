class_name TestCase
extends RefCounted
## Minimal assertion base for headless tests. Methods named `test_*` are run
## by tests/test_runner.gd; `before_each` runs before each of them.

var failures: Array[String] = []
var current_test := ""


func before_each() -> void:
	pass


func check(condition: bool, message: String = "expected condition to be true") -> void:
	if not condition:
		failures.append("%s: %s" % [current_test, message])


func check_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if typeof(actual) != typeof(expected) and not (_is_number(actual) and _is_number(expected)):
		failures.append("%s: %s expected %s (%s) got %s (%s)" % [current_test, message,
				expected, type_string(typeof(expected)), actual, type_string(typeof(actual))])
	elif actual != expected:
		failures.append("%s: %s expected %s got %s" % [current_test, message, expected, actual])


func check_near(actual: float, expected: float, tolerance: float = 0.001, message: String = "") -> void:
	if absf(actual - expected) > tolerance:
		failures.append("%s: %s expected ~%s got %s" % [current_test, message, expected, actual])


func _is_number(value: Variant) -> bool:
	return value is int or value is float
