#Updater

此插件，将各个不同环境、不同版本的程序包、资源包存放到远程服务器上，通过静态资源URL的形式可以提供下载和更新。

插件更新面板

## 服务器信息
包含服务器IP、端口、用户名、服务器路径。将生成后的程序、资源包上传到指定的服务器的路径上，这部分是留给编辑器用的。

生成好的资源包会根据项目环境、平台、版本号存放到不同的目录，具体路径如下：

服务器路径/项目环境/平台/版本号/包名。

## 资源包信息
包含资源根URL、项目名称和项目环境。资源根URL表示配置的可以从该URL获取到静态文件的地址。

程序包的程序将根据资源包信息去检查版本信息、下载对应版本的资源文件。

## 资源列表
点击扫描导出，会把项目配置的所有导出扫描一遍，并且根据不同平台区分开来。

点击新版本，会将版本号新加一位，末尾有版本戳。

点击发布，将会指定导出平台所有的导出内容，并且上传到服务器对应路径。
