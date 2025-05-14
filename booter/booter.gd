extends Node2D

func _ready() -> void:
	VersionManager.load_version()
	
## 检查资源包
func _check_res():
	VersionManager.download_end.connect(self.download_end)
	$CanvasLayer/version.text = VersionManager.get_version_id()
	if VersionManager.remote_check_http_error!=0:
		show_msg("检查远程版本错误,错误码 %d" % VersionManager.remote_check_http_error)
		return

	VersionManager.check_reset_all_ok()
	if VersionManager.boot_need_update():
		print("需要更新启动器")
		show_boot_update()
		return
	
	if !VersionManager.pck_need_update():
		print("没有资源需要更新！！")
		$CanvasLayer/AnimationPlayer.play("to_main")
	else:
		print("需要更新资源!!")
		$CanvasLayer/AnimationPlayer.play("to_updating")

func show_msg(text: String):
	$CanvasLayer/ColorRect3.hide()
	$CanvasLayer/Msg.text = text

func show_boot_update():
	$CanvasLayer/ColorRect3.hide()
	$CanvasLayer/UpdateBoot.show()

func start_update():
	$CanvasLayer/ColorRect3/Label.show()
	VersionManager.download_check_pcks()
	$CanvasLayer/DownCheck.start()
	
func download_end(result: int):
	if result==0:
		down_success()
		$CanvasLayer/DownCheck.stop()
		$CanvasLayer/AnimationPlayer.play("update_to_main")
	else:
		show_msg("下载错误，错误码 %d" % result)
		$CanvasLayer/DownCheck.stop()

func _on_update_boot_pressed() -> void:
	var dest_uri = VersionManager.get_remote_boot_version_uri()
	OS.shell_open(dest_uri)

func goto_main():
	VersionManager.load_packages()
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func down_success():
	$CanvasLayer/ColorRect3/Label/ProgressBar/Label2.text=""
	$CanvasLayer/ColorRect3/Label/ProgressBar/Label.text=""
	$CanvasLayer/ColorRect3/Label/ProgressBar/Label3.text = "已完成"
	

func _on_down_check_timeout() -> void:
	var down_ock = VersionManager.get_downloaded_res()
	var down_total = VersionManager.get_total_res()
	if down_ock==down_total:
		return
	var down = VersionManager.get_downloaded_bytes() / 1024.0 # 默认KB
	var total = VersionManager.get_total_size() / 1024.0  # 默认KB
	var format_str = ""
	if total >= 1024.0:
		total = total / 1024.0
		down = down / 1024.0
		format_str = "%.2fMB / %.2fMB"
	else:
		format_str = "%.0fKB / %.0fKB"
		
	$CanvasLayer/ColorRect3/Label/ProgressBar/Label3.text= format_str % [down,total]
	if down_ock==down_total:
		$CanvasLayer/ColorRect3/Label/ProgressBar.value = (down*100.0/total)
	else:
		$CanvasLayer/ColorRect3/Label/ProgressBar.value = 100.0
	var speed = VersionManager.get_download_speed() / 1024.0
	var speed_fr = ""
	if speed>=1024.0:
		speed = speed/1024.0
		speed_fr = "%.2f MB/s"
	else:
		speed_fr = "%.0f KB/s"
	$CanvasLayer/ColorRect3/Label/ProgressBar/Label2.text = speed_fr % speed
	$CanvasLayer/ColorRect3/Label/ProgressBar/Label.text = "%d / %d" % [down_ock+1,down_total]
