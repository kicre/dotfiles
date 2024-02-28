# 定义要操作的文件
$filePath = "$env:scoop\persist\aria2\aria2.conf"
# 定义要获取的文本的网址
$url = "https://cf.trackerslist.com/all_aria2.txt"

# 获取网页文本，并从中提取最后一行内容
$webContent = Invoke-WebRequest -Uri $url
$trackerList = $webContent.Content.Split("`n")[-1]

# 打开文件
$fileContent = Get-Content -Path $filePath

# 删除最后两行内容
$fileContent = $fileContent[0..($fileContent.Count - 2)]

# 在文件末尾添加新内容
$fileContent += "bt-tracker=$trackerList"

# 将新内容写回文件
Set-Content -Value $fileContent -Path $filePath