@tool
class_name VersionControlDock
extends Control

const server_config_path = "res://server.json"
const resource_config_path = "res://res.config.tres"

## 当前服务器配置字典
var server_config: Dictionary 

## 当前支持的平台映射
var real_platform = {
	"Windows Desktop" = "windows",
	"Android" = "android"
}

## 资源URI信息配置
var resource_config: = ResourceConfigRes.new()

## 全局版本
var global_version = ""

## 数据存储位置【res://server.json，仅在编辑器中可使用，作为版本控制提交的配置】
## 更新控制【JSON形式避免导出时被带入】
## - 更新服务器信息（ip、port、user、remote_path）
##
## 发布控制【读取资源包中的最新版本】
## - 导入export中的资源包配置
## - 重置版本
## - 发布对应平台
## 
## 资源包信息【res://res.config.tres Booter程序必须需要的】
## - 资源服务器url地址 http://assets.natsufumij.cn
## - 项目名称 project_name

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	load_server_config()
	load_resource_config()
	_on_scan_export_pressed()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_save_server_pressed() -> void:
	server_config = {
		ip = $ScrollContainer/VBoxContainer/server/serverIp/LineEdit.text,
		port = $ScrollContainer/VBoxContainer/server/serverPort/LineEdit.text,
		user = $ScrollContainer/VBoxContainer/server/serverUser/LineEdit.text,
		remote_path = $ScrollContainer/VBoxContainer/server/serverPath/LineEdit.text
	}
	var file = FileAccess.open(server_config_path,FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(server_config))
		file.close()
		print("保存服务器信息成功，信息如下:\n",server_config)

func load_server_config():
	# 先重置
	server_config = {
		ip = "",
		port = "",
		user = "",
		remote_path = ""
	}
	var res = ResTool.new()
	res.load_json_with_default(server_config_path,server_config)
	$ScrollContainer/VBoxContainer/server/serverIp/LineEdit.text = server_config["ip"]
	$ScrollContainer/VBoxContainer/server/serverPort/LineEdit.text = server_config["port"]
	$ScrollContainer/VBoxContainer/server/serverUser/LineEdit.text = server_config["user"]
	$ScrollContainer/VBoxContainer/server/serverPath/LineEdit.text = server_config["remote_path"]
	print("服务器信息如下:\n",server_config)

func save_resource_config():
	resource_config.project_name = $ScrollContainer/VBoxContainer/pcks/projectN/LineEdit.text
	resource_config.resource_uri = $ScrollContainer/VBoxContainer/pcks/pckUri/LineEdit.text
	var err = ResourceSaver.save(resource_config,resource_config_path)
	if err != OK:
		printerr("保存资源URL信息失败！")
	else:
		print("保存资源URL信息，信息如下:\n",inst_to_dict(resource_config))


func load_resource_config():
	## 先重置
	resource_config = ResourceConfigRes.new()
	if FileAccess.file_exists(resource_config_path):
		resource_config = load(resource_config_path)
	else:
		print("资源配置不存在,使用默认的")
	$ScrollContainer/VBoxContainer/pcks/projectN/LineEdit.text = resource_config.project_name
	$ScrollContainer/VBoxContainer/pcks/pckUri/LineEdit.text = resource_config.resource_uri
	_refresh_env_options()

func _on_scan_export_pressed() -> void:
	var res = ResTool.new()
	var platform = res.load_export_platform()
	$ScrollContainer/VBoxContainer/packages/pckPlatform/OptionButton.clear()
	for plat in platform:
		$ScrollContainer/VBoxContainer/packages/pckPlatform/OptionButton.add_item(plat)
		check_boot_version(plat)
	if not platform.is_empty():
		_refresh_res_list(0)


func check_boot_version(platform: String):
	var path = "res://booter.version."+real_platform[platform]+".tres"
	if !FileAccess.file_exists(path):
		var ver = BooterVer.new()
		ver.version = ""
		ResourceSaver.save(ver,path)
	

func _refresh_res_list(plat: int):
	var res = ResTool.new()
	var platform = $ScrollContainer/VBoxContainer/packages/pckPlatform/OptionButton.get_item_text(plat)
	var pck_list = res.load_export_packages(platform)
	var pcks: = $ScrollContainer/VBoxContainer/packages/platformPcks
	var pck_temp: = $ScrollContainer/VBoxContainer/packages/platformPckTemp
	## 删除列表
	for item in pcks.get_children():
		pcks.remove_child(item)
		item.queue_free()
	## 添加列表
	for pname in pck_list:
		var pck_t = pck_temp.duplicate()
		pck_t.name = pname
		pcks.add_child(pck_t)
		pck_t.get_node("Label").text = pname
		pck_t.get_node("Label2").text = "未知"
		pck_t.get_node("Button").pressed.connect(self.pck_version_to_new.bind(pname))

func pck_version_to_new(pck_name: String):
	print("pck ",pck_name," check new version!")
	var pcks: = $ScrollContainer/VBoxContainer/packages/platformPcks
	for item in pcks.get_children():
		if item.name==pck_name:
			## 设置版本
			item.get_node("Label2").text = global_version
			## 再次设为不能点击
			item.get_node("Button").disabled = true
			break

func _on_platform_selected(index: int) -> void:
	_refresh_res_list(index)

func _on_prepare_new_version_pressed() -> void:
	var res = ResTool.new()
	var type = $ScrollContainer/VBoxContainer/packages/platformPckTemp2/OptionButton2.get_selected_id()
	global_version = $ScrollContainer/VBoxContainer/packages/platformPckTemp2/Label2.text
	## 计算新版本号
	var nv = res.calc_next_global_version(global_version,type)
	$ScrollContainer/VBoxContainer/packages/platformPckTemp2/Label2.text = nv
	global_version = nv
	var pcks: = $ScrollContainer/VBoxContainer/packages/platformPcks
	for item in pcks.get_children():
		var but = item.get_node("Button")
		## 设置启用
		but.disabled = false

func _on_reset_version_pressed() -> void:
	global_version = "0.0.0.0"
	$ScrollContainer/VBoxContainer/packages/platformPckTemp2/Label2.text = global_version
	var pcks: = $ScrollContainer/VBoxContainer/packages/platformPcks
	for item in pcks.get_children():
		## 设置版本
		item.get_node("Label2").text = global_version
		## 再次设为不能点击
		item.get_node("Button").disabled = true

func get_selected_platform_id()->String:
	var op: OptionButton = $ScrollContainer/VBoxContainer/packages/pckPlatform/OptionButton
	var id = op.get_selected_id()
	if id==-1:
		return ""
	var text = op.get_item_text(id)
	var real_pt_id = real_platform[text]
	return real_pt_id	

func _on_publish_pressed() -> void:
	var real_pt_id = get_selected_platform_id()
	var res = ResTool.new()
	var pcks: = $ScrollContainer/VBoxContainer/packages/platformPcks
	## 预生成文件夹
	var remote_folder = server_config["remote_path"]
	if not DirAccess.dir_exists_absolute("export/dist/temp"):
		DirAccess.make_dir_recursive_absolute("export/dist/temp")
	## 预生成环境文件夹
	if not DirAccess.dir_exists_absolute("export/dist/"+resource_config.project_env):
		DirAccess.make_dir_recursive_absolute("export/dist/"+resource_config.project_env)
	
	## 创建目标目录
	res.upload_file("export/dist/temp",remote_folder,server_config["port"],server_config["ip"],server_config["user"])
	remote_folder=remote_folder+"/"+resource_config.project_env
	res.upload_file("export/dist/temp",remote_folder,server_config["port"],server_config["ip"],server_config["user"])
	res.upload_file("export/dist/temp",remote_folder+"/"+real_pt_id,server_config["port"],server_config["ip"],server_config["user"])
	res.upload_file("export/dist/temp",remote_folder+"/"+real_pt_id+"/"+global_version,server_config["port"],server_config["ip"],server_config["user"])

	var list: Array[Dictionary] = []
	var run_dict = res.load_export_executables()
	for item in pcks.get_children():
		## 设置版本
		var item_v = item.get_node("Label2").text
		var runnable = run_dict.has(item.name)
		if item_v==global_version:
			if runnable:
				_save_booter_tres(item_v,real_pt_id)
			res.export_one(resource_config.project_env,global_version,item.name,real_pt_id,runnable,remote_folder,server_config["port"],server_config["ip"],server_config["user"])
		list.append(get_export_dict(resource_config.project_env,real_pt_id,item.name,runnable,item_v))
		
	## 输出版本信息
	res.output_version_json(real_pt_id,global_version,list,server_config,resource_config.project_env)

func get_export_dict(env:String,platform:String,name:String, is_booter:bool,ver: String)->Dictionary:
	var runnable_format = {
		"windows" = "exe",
		"android" = "apk"
	}
	var package_dict = {}
	var package = name+"."+ (runnable_format[platform] if is_booter else "pck")
	package_dict["name"]=name
	package_dict["package"]=package
	package_dict["version"]=ver
	package_dict["type"]="Booter" if is_booter else "package"
	var dest_path = "export/dist/"+env+"/"+platform+"/"+ver+"/"+package
	package_dict["size"]=get_file_size(dest_path)
	
	return package_dict

func get_file_size(file_path: String) -> int:
	if FileAccess.file_exists(file_path):  # 先检查文件是否存在
		var file = FileAccess.open(file_path, FileAccess.READ)
		if file:
			var size = file.get_length()  # 获取字节数
			file.close()  # 显式关闭文件（可选）
			return size
		else:
			print("无法打开文件：", file_path)
			return -1  # 返回错误码
	else:
		print("文件不存在：", file_path)
		return -1

func _on_sync_pressed() -> void:
	var res = ResTool.new()
	var platform = get_selected_platform_id()
	var version_uri = resource_config.resource_uri+"/"+resource_config.project_name+"/"+resource_config.project_env+ "/Version_"+platform+".json"
	var remote_js = await res.load_remote_json(version_uri,self)
	var version_map = {}
	for item in remote_js["packages"]:
		if item.has("version"):
			version_map[item["name"]]=item["version"]
		if item["type"]=="Booter":
			_save_booter_tres(item["version"],platform)
	global_version = remote_js["version"]
	$ScrollContainer/VBoxContainer/packages/platformPckTemp2/Label2.text = global_version
	var pcks: = $ScrollContainer/VBoxContainer/packages/platformPcks
	for item in pcks.get_children():
		if version_map.has(item.name):
			## 设置版本
			item.get_node("Label2").text = version_map[item.name]
			## 再次设为不能点击
			item.get_node("Button").disabled = true


func _save_booter_tres(version: String,platform: String):
	var dest_path = "res://booter.version."+platform+".tres"
	var ver = BooterVer.new()
	ver.version = version
	ResourceSaver.save(ver,dest_path)


func _refresh_env_options():
	var option: OptionButton = $ScrollContainer/VBoxContainer/pcks/projectEnv/LineEdit
	var moto_select = resource_config.project_env
	var list: Array[String] = resource_config.project_env_list
	if not list:
		list = []
		resource_config.project_env_list=list
	option.clear()
	option.select(-1)
	if list:
		for i in range(0,list.size()):
			var item = list[i]
			option.add_item(item)
			if item==moto_select:
				option.select(i)


func _on_project_env_selected(index: int) -> void:
	var option: OptionButton = $ScrollContainer/VBoxContainer/pcks/projectEnv/LineEdit
	var sid = option.get_selected_id()
	if sid==-1:
		return
	var ind = option.get_item_index(sid)
	var indtext = option.get_item_text(sid)
	resource_config.project_env = indtext
