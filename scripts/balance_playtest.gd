extends SceneTree

const PlaytestReporter = preload("res://scripts/playtest_reporter.gd")


func _initialize() -> void:
	var reporter := PlaytestReporter.new()
	var report := reporter.build_report()
	print(JSON.stringify(report, "  ", true))
	quit(0)
