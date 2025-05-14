## 下载时，会自动拼接名称
## 如果资源为aaa.pck,那么下载地址为 resource_uri/project_name/aaa.pck

class_name ResourceConfigRes
extends Resource

## 资源下载URI
@export var resource_uri: String
## 项目名称
@export var project_name: String
## 项目当前环境
@export var project_env: String
## 项目列表
@export var project_env_list: Array[String] = []
