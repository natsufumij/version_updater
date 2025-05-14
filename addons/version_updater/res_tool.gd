class_name ResTool
extends Object

signal download_end(result:int,url: String)

func load_json_with_default(path: String, default_dict: Dictionary) -> Dictionary:
	if not FileAccess.file_exists(path):
		return default_dict
	var file = FileAccess.open(path,FileAccess.READ)
	if file == null:
		print("文件打开失败：", FileAccess.get_open_error())
		return default_dict
	 # 获取文件内容
	var content = file.get_as_text()
	file.close()
	# 解析 JSON
	var json = JSON.new()
	var parse_result = json.parse(content)
	if parse_result != OK:
		print("JSON 解析错误：", json.get_error_message(), " 行：", json.get_error_line())
		return default_dict

	# 获取解析后的数据（字典或数组）
	var data: = json.data as Dictionary
	for key in default_dict:
		if data.has(key):
			default_dict[key]=data[key]
	return default_dict

func load_export_platform() -> Array:
	var dict = {}
	var cf := ConfigFile.new()
	cf.load("res://export_presets.cfg")
	for i in range(0,100):
		var sec = "preset."+String.num_int64(i)
		if cf.has_section(sec):
			var plat = cf.get_value(sec,"platform")
			dict[plat] = ''
		else:
			break
	return dict.keys()

func load_export_packages(platform: String) -> Array:
	var d = []
	var cf := ConfigFile.new()
	cf.load("res://export_presets.cfg")
	for i in range(0,100):
		var sec = "preset."+String.num_int64(i)
		if cf.has_section(sec):
			var plat = cf.get_value(sec,"platform")
			if plat != platform:
				continue
			#var runnable = cf.get_value(sec,"runnable",false)
			var name = cf.get_value(sec,"name")
			d.append(name)
		else:
			break
	return d

## 获取所有可执行的导出名称字典
func load_export_executables() -> Dictionary:
	var d = {}
	var cf := ConfigFile.new()
	cf.load("res://export_presets.cfg")
	for i in range(0,100):
		var sec = "preset."+String.num_int64(i)
		if cf.has_section(sec):
			var name = cf.get_value(sec,"name","")
			var runnable = cf.get_value(sec,"runnable",false)
			if runnable:
				d[name] = "run"
		else:
			break
	return d

## 计算下一个全局版本号
## 版本号构成如下: X.X.XX.XXXXXXXX(主版本号、大版本号、小版本、版本戳)
func calc_next_global_version(version: String,type: int) -> String:
	if version==null:
		version = ""
	## 版本戳
	var split = version.split(".")
	## 最后以为是版本戳
	var ves = [0,0,0,0]
	if not split.is_empty():
		for i in range(0,split.size()):
			if i>=ves.size():
				break
			var st = split[i] as String
			ves[i]=st.to_int()
	var ind = ves.size()-type-2
	ves[ind]=ves[ind]+1
	if ind<ves.size()-2:
		for i in range(ind+1,ves.size()-1):
			ves[i]=0

	if ind>0:
		for i in range(ind,0,-1):
			if ves[i]>100:
				ves[i]=ves-100
				ves[i-1]+=1
			else:
				break
	# 计算版本戳
	ves[ves.size()-1]=randi() % 10000
	var version_str:= ""
	for i in ves:
		version_str+= (String.num_int64(i)+".")
	version_str = version_str.substr(0,version_str.length()-1)
	return version_str


func export_one(env: String,ver: String,name: String,platform: String,is_booter: bool,remote_folder: String, port: String,ip: String, user: String):
	var runnable_format = {
		"windows" = "exe",
		"android" = "apk"
	}
	var package = name+"."+ (runnable_format[platform] if is_booter else "pck")

	print("发布 ",package," 版本 ",ver)
 # 获取 Godot 可执行文件路径
	var godot_path = OS.get_executable_path()
	var dest_path = "export/dist/"+env+"/"+platform+"/"+ver
	if !DirAccess.dir_exists_absolute(dest_path):
		DirAccess.make_dir_recursive_absolute(dest_path)
	
	# 构建命令行参数
	var args = [
		"--headless",
		"--export-debug" if is_booter else "--export-pack",
		name,
		dest_path+"/"+package
	]
	
	# 执行命令
	var exit_code = OS.execute(godot_path, args, [], true,true)
	print("%s 导出完成，退出码: %d" % [name,exit_code])
	if exit_code==0:
		var dest_file = dest_path+"/"+package
		var remote_file = remote_folder+"/"+platform+"/"+ver+"/"+package
		## 上传输出结果
		upload_file(dest_file,remote_file,port,ip,user)

##
## 需要有scp命令
## 并且远程服务器已经加入当前服务器的ssh_key
##
## 示例命令如下：
## 客户端
## ssh-keygen -t rsa -b 2048
## 复制到服务器
## # 假设远程主机名为 example.com，用户名为 user
## scp ~/.ssh/id_rsa.pub user@example.com:~/
## 
## 在远程服务器上执行以下命令：
## mkdir -p ~/.ssh && chmod 700 ~/.ssh
## cat ~/id_rsa.pub >> ~/.ssh/authorized_keys
## chmod 600 ~/.ssh/authorized_keys
## rm ~/id_rsa.pub
## 
func upload_file(file_path: String, dest_path: String, port: String,ip: String, user: String):
	var args = [
		"-r",
		"-P",port,
		file_path,
		user+"@"+ip+":"+dest_path
	]
	print("update ",args)
	# 执行命令
	var exit_code = OS.execute("scp", args, [], true,true)
	print("上传结果 ",dest_path,",",exit_code)

func _command_execute(program: String, args: Array) -> int:
	var exit_code = OS.execute("scp", args, [], true,true)
	print(program," ",args," >> result ",exit_code)
	return exit_code

## Version_platform.json
func output_version_json(platform: String,version: String, packages: Array[Dictionary],server_config: Dictionary,env: String):
	var ip = server_config["ip"]
	var port = server_config["port"]
	var remote_path = server_config["remote_path"]+"/"+env
	var user = server_config["user"]
	
	var dict = {
		version = version,
		packages = packages
	}
	var filename = "Version_"+platform+".json"
	var export_path = "export/dist/"+env+"/"+filename
	save_json(dict,export_path)
	var remote_file_path = remote_path+"/"+filename
	upload_file(export_path,remote_file_path,port,ip,user)

## 加载远程json
func load_remote_json(url: String,node: Node)->Dictionary:
	print("load url >> ",url)
	var dest = {
		"version": "",
		"packages": []
	}
	var http = HTTPRequest.new()
	node.add_child(http)
	http.request(url)
	var result = await http.request_completed
	http.queue_free()
	var response_code = result[1]
	var body = result[3]
	if response_code == 200:
		var json_str = body.get_string_from_utf8()
		var dict= JSON.parse_string(json_str) as Dictionary
		for key in dest:
			if dict.has(key):
				dest[key]=dict[key]
		return dest
	else:
		dest["error"]=result[0]
		push_error("HTTP 错误码: ", response_code)
		return dest

# 保存 JSON 到指定路径
func save_json(data, path: String) -> bool:
	# 1. 将数据转换为 JSON 字符串
	var json_str: String
	if typeof(data) == TYPE_DICTIONARY or typeof(data) == TYPE_ARRAY:
		json_str = JSON.stringify(data, "\t")  # 使用缩进格式化
	else:
		push_error("无效的数据类型，仅支持 Dictionary 或 Array")
		return false
	
	# 2. 处理路径
	var dir_path = path.get_base_dir()
	var file_name = path.get_file()
	
	# 创建目录（如果不存在）
	var dir = DirAccess.open(dir_path)
	if not dir:
		dir = DirAccess.make_dir_recursive_absolute(dir_path)
		if dir != OK:
			push_error("目录创建失败：", dir_path)
			return false
	
	# 3. 写入文件
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(json_str)
		file.close()
		print("JSON 保存成功：", path)
		return true
	else:
		var error = FileAccess.get_open_error()
		push_error("文件写入失败：%s (错误码：%d)" % [error_string(error), error])
		return false

func download_obj(url: String, dest_file: String,node: Node):
	var download_http: HTTPRequest = HTTPRequest.new()
	download_http.name = "http_"
	node.add_child(download_http)
	download_http.download_file = dest_file
	download_http.request_completed.connect(download_http.queue_free)
	download_http.request(url)
	var datas = await download_http.request_completed	
	download_http.queue_free()
	print("下载结束, ",url,",",datas[0])
	download_end.emit(datas[0],url,download_http.get_body_size())

func get_total_size(node: Node)->int:
	var children = node.get_children()
	var total = 0
	for item in children:
		if item.name.begins_with("http_"):
			var ht = item as HTTPRequest
			total = total + ht.get_body_size()
	return total

func get_down_bytes(node: Node)->int:
	var children = node.get_children()
	var total = 0
	for item in children:
		if item.name.begins_with("http_"):
			var ht = item as HTTPRequest
			total = total + ht.get_downloaded_bytes()
	return total
