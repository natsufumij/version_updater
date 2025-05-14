extends Node

signal download_end(result: int)

const version_path = "user://version.json"
const pck_save_path = "user://version";

var res_config:ResourceConfigRes
## 当前启动器版本
var now_boot_version = ""

## 当前运行版本
var now_version = {
	version = "",
	packages = []
}

## 远程版本
var remote_version= {
	version = "",
	packages = []
}
## 检查远程版本错误
var remote_check_http_error:int = 0

## 当前运行环境
var now_platform: String

var httphelp: = ResTool.new()
var downspeed_check: = Timer.new()

func _ready() -> void:
	httphelp.download_end.connect(self.down_ok)
	add_child(downspeed_check)
	downspeed_check.wait_time = 0.5
	downspeed_check.timeout.connect(self.download_check_speed)

## 加载版本信息 从user://version.json 里面加载
## 加载运行环境
func load_version():
	now_platform = OS.get_name().to_lower()
	var res = ResTool.new()
	now_version = res.load_json_with_default(version_path,{
		"version": "",
		"packages": []
	})
	res_config = load("res://res.config.tres")
	var bo = load("res://booter.version."+now_platform+".tres") as BooterVer
	now_boot_version = bo.version
	await _load_remote_version()

## 获取当前版本信息
## Env.Platform.BootVersion_PckVersion
func get_version_id() ->String:
	return res_config.project_env+"."+now_platform+"."+now_boot_version+"_"+now_version["version"]

## 加载远程版本信息
func _load_remote_version():
	var res = ResTool.new()
	var rem_path = res_config.resource_uri+"/"+res_config.project_name+"/"+res_config.project_env+"/Version_"+now_platform+".json"
	remote_version = await res.load_remote_json(rem_path,self)
	print("remote ",remote_version)
	if remote_version.has("error"):
		remote_check_http_error = remote_version["error"]

## 更新版本信息 到user://version.tres
func _update_version():
	var res = ResTool.new()
	res.save_json(now_version,version_path)

func update_to_remote():
	now_version = remote_version.duplicate()
	_update_version()
	clean_res_packages()

## 加载全部资源包
func load_packages():
	if now_version["packages"]:
		for item in now_version["packages"]:
			var type = item["type"]
			var packages = item["package"]
			var version = item["version"]
			if type!="Booter":
				var path = pck_save_path+"/"+version+"/"+packages
				if FileAccess.file_exists(path):
					var er = ProjectSettings.load_resource_pack(path)
					print("加载资源包 ",path," ",er)
				else:
					print("资源包找不到 ",path)

func clean_res_packages():
	var package_dict = {}
	for item in now_version["packages"]:
		var type = item["type"]
		var packages = item["package"]
		var version = item["version"]
		if type!="Booter":
			package_dict[packages]=version

	var version_dirs = DirAccess.get_directories_at(pck_save_path)
	for dir in version_dirs:
		var version_name = dir
		var path = pck_save_path+"/"+dir
		var files = DirAccess.get_files_at(path)
		for file in files:
			var need_remove = false
			if package_dict.has(file):
				var version = package_dict[file]
				if version!=version_name:
					## 删除旧版本
					need_remove =true
			else:
				need_remove = true
			if need_remove:
				var rpath = path+"/"+file
				DirAccess.remove_absolute(rpath)
				print("删除文件 ",rpath)
		var fs = DirAccess.get_files_at(path)
		if fs.is_empty():
			print("移除版本文件夹 ",path)
			DirAccess.remove_absolute(path)

var check_all = {
	need_update_booter = "no"
}
func check_reset_all_ok():
	var result = {
		need_update_booter= "no",
		need_update_pcks = {}
	}
	if OS.has_feature("editor"):
		check_all = result
		return

	var pcks_dict = {}
	for item in now_version["packages"]:
		pcks_dict[item["package"]]=item["version"]

	for item in remote_version["packages"]:
		var package = item["package"]
		var version = item["version"]
		var size = item["size"]
		var type = item["type"]
		if type=="Booter":
			if now_boot_version!=version:
				print("启动器需要更新！！")
				result["need_update_booter"]=version
				break
		else:
			var path = pck_save_path+"/"+version+"/"+package
			## 文件不存在或者不相同，则更新
			if !FileAccess.file_exists(path) or !check_file_size(path,size):
				result["need_update_pcks"][package]=version
	check_all=result
	if !pck_need_update():
		update_to_remote()

func check_file_size(path:String, size: int) -> bool:
	var file = FileAccess.open(path,FileAccess.READ)
	return file.get_length()==size

func boot_need_update()->bool:
	return check_all["need_update_booter"]!="no"

func pck_need_update()->bool:
	return !check_all["need_update_pcks"].is_empty()

func get_remote_boot_version_uri()->String:
	var ver = check_all["need_update_booter"]
	var b_package = ""
	for item in VersionManager.remote_version["packages"]:
		if item["type"]=="Booter":
			b_package = item["package"]	
	var res_config = res_config
	var now_p = now_platform
	var dest_uri = res_config.resource_uri+"/"+res_config.project_name+"/"+res_config.project_env+"/"+now_p+"/"+ver+"/"+b_package
	return dest_uri

func download_check_pcks():
	download_pcks(check_all["need_update_pcks"])


## 获取远程版本的文件尺寸
func get_remote_version_file_size(package:String) -> int:
	for item in remote_version["packages"]:
		var pac = item["package"]
		if pac==package:
			return item["size"]
	return 0

var downs
var down_pck_total = 0
var down_pck_ok = 0
var down_totals = 0
var real_totals = 0

func download_pcks(dict: Dictionary):
	down_totals = 0
	down_speed = 0
	real_totals = 0
	down_pck_total = dict.size()
	down_pck_ok = 0
	if !DirAccess.dir_exists_absolute(pck_save_path):
		DirAccess.make_dir_absolute(pck_save_path)
	
	downspeed_check.start()
	var platform = now_platform
	downs = {}
	for key in dict:
		## http://xxx.com/avc/1.2.0/Booter.exe
		var ver = dict[key]
		var dest_path = pck_save_path+"/"+ver
		if !DirAccess.dir_exists_absolute(dest_path):
			DirAccess.make_dir_absolute(dest_path)
		dest_path = dest_path+"/"+key
		print("ver,path ",ver,",",dest_path)
		var remote_version_uri = res_config.resource_uri+"/"+res_config.project_name+"/"+res_config.project_env
		var dest_uri = remote_version_uri+"/"+platform+"/"+dict[key]+"/"+key
		downs[dest_uri] = ver
		real_totals += get_remote_version_file_size(key)
		httphelp.download_obj(dest_uri,dest_path,self)

func down_ok(result: int, url: String, total:int):
	if result==0:
		downs.erase(url)
		down_totals+=total
		down_pck_ok+=1
		if downs.is_empty():
			print("全部下载完毕")
			download_end.emit(result)
			downspeed_check.stop()
	else:
		## 失败时，返回失败信息
		download_end.emit(result)
		downspeed_check.stop()


## 检查下载速度
var last_bytes: = 0
var down_speed: = 0
func download_check_speed():
	var elasp = downspeed_check.wait_time
	if last_bytes==0:
		last_bytes = get_downloaded_bytes()
		return
	var now_down = get_downloaded_bytes()
	down_speed = (now_down-last_bytes)/elasp
	last_bytes = now_down

func get_total_size() ->int:
	return real_totals

func get_downloaded_bytes() ->int:
	return httphelp.get_down_bytes(self)+down_totals

func get_total_res() ->int:
	return down_pck_total

func get_downloaded_res() ->int:
	return down_pck_ok

func get_download_speed()->int:
	return down_speed
