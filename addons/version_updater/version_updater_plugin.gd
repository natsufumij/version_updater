@tool
extends EditorPlugin

var version_control_dock: VersionControlDock

func _enter_tree():
	# 添加版本控制面板
	var dock: = load("res://addons/version_updater/version_control_dock.tscn") as PackedScene
	version_control_dock = dock.instantiate() as VersionControlDock
	add_control_to_dock(DOCK_SLOT_LEFT_BR, version_control_dock)
	# 添加版本管理器单例（仅提供下载版本文件、下载资源、加载资源、提供给游戏使用）
	add_autoload_singleton("VersionManager", "res://addons/version_updater/version_manager.gd")


func _exit_tree():
	# 移除版本控制面板
	remove_control_from_docks(version_control_dock)
	version_control_dock.queue_free()
	# 移除版本管理器单例
	remove_autoload_singleton("VersionManager")
