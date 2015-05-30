 # @author littocats
 # @date 2015-05-23
 # 一个基于Node.js的简单文件服务器

fs    	= require "fs"
http    = require "http"
url     =require "url"
path    =require "path"
mime    =require("./mime").mime

# www 根目录
root=__dirname
host="127.0.0.1"
port="8888"
    
if !fs.existsSync root
  console.log  root+"文件夹不存在，请重新制定根文件夹！"
  process.exit()

 # 显示文件夹下面的文件
listDirectory = (parentDirectory,req,res) ->
	fs.readdir parentDirectory,(error,files)->
		files = ((files)->
			ret = []
			for file in files
				ret.push file if file.match /^[^\.]/
			ret
		) files
		body = formatBody parentDirectory,files
		res.writeHead 200,{
			"Content-Type":"text/html;charset=utf-8",
			"Content-Length":Buffer.byteLength(body,'utf8'),
			"Server":"NodeJs("+process.version+")"
		}
		res.write body,'utf8'
		res.end()

# 显示文件内容
showFile = (file,req,res)->
	fs.readFile file,'binary',(err,file)->
		contentType = mime.lookupExtension path.extname file
		res.writeHead 200,{
			"Content-Type":contentType,
			"Content-Length":Buffer.byteLength(file,'binary'),
			"Server":"NodeJs("+process.version+")"
		}
		res.write file,"binary"
		res.end()

# 在Web页面上显示文件列表，格式为<ul><li></li><li></li></ul>
formatBody = (parent,files)->
	length = files.length
	'''
	<!doctype>
	<html>
		<head>
			<meta http-equiv='Content-Type' content='text/html;charset=utf-8'></meta>
 			<title>CofeeMobile 服务器</title>
		</head>
		<body width='100%'>
			<div style='position:relative;width:98%;bottom:5px;height:25px;background:#A3BF00'>
				<div style='margin:10 auto;height:100%;line-height:25px;text-align:left'>'''+parent+'''</div>
			</div>
			<ul>

	''' + (if parent isnt root then "<li><a href='../'>"+"../"+"</a></li>" else "") + 
	((flies)-> ((file) ->
			stat = fs.statSync path.join parent, file
			file = if stat.isDirectory file then path.basename(file)+"/" else path.basename file
			"<li><a href='"+file+"'>"+file+"</a></li>"
		) file for file in files
	)(files).join('') +
	'''
			</ul>
			<div style='position:relative;width:98%;bottom:5px;height:25px;background:gray'>
				<div style='margin:0 auto;height:100%;line-height:25px;text-align:center'>Powered By Node.js</div>
			</div>
		</body>
	</html>
	'''

# 如果文件找不到，显示404错误
write404 = (req,res) ->
	body = "文件不存在:-("
	res.writeHead 404,{
		"Content-Type":"text/html;charset=utf-8",
		"Content-Length":Buffer.byteLength(body,'utf8'),
		"Server":"NodeJs("+process.version+")"
	}
	res.write body
	res.end()

# 创建服务器
server = http.createServer (req,res) ->
	# 将url地址的中的%20替换为空格，不然Node.js找不到文件
	pathname = url.parse(req.url).pathname.replace(/%20/g,' ')
	re = /(%[0-9A-Fa-f]{2}){3}/g
	# 能够正确显示中文，将三字节的字符转换为utf-8编码
	pathname = pathname.replace re,(word)->
		buffer=new Buffer 3
		array=word.split '%'
		array.splice 0,1
		array.forEach (val,index)->
			buffer[index]=parseInt('0x'+val,16)
		return buffer.toString 'utf8'
	console.log pathname
	if pathname is '/'
		listDirectory root,req,res
	else
		filename=path.join root,pathname
		fs.exists filename,(exists)->
			if !exists
				console.log  '找不到文件'+filename
				write404 req,res
			else
				fs.stat filename,(err,stat)->
					showFile(filename,req,res) if stat.isFile()
					listDirectory(filename,req,res) if stat.isDirectory()

server.listen port,host
console.log  "服务器开始运行 http://"+host+":"+port
