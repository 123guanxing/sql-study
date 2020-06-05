# 部署脚本

########********************************************************########
param
(
    # 是否需要解压文件: 1 true, 0 false
    [int]$isDecomposeFile,
    #压缩文件所在目录
    [string]$sourceFileDir,
    #解压文件目录
    [string]$targetFileDir
)
if ($targetFileDir -eq "") {
    echo "param error"
    echo "Usage:"
    echo "powershell -ExecutionPolicy ByPass -File deploy.ps1 -isDecomposeFile 1 -sourceFileDir XXX -targetFileDir XXX"
    echo "powershell -ExecutionPolicy ByPass -File deploy.ps1 -targetFileDir XXX"
    Exit
}

#$targetFileDir = "D:\Download\test"
#$isDecomposeFile = 0
#$sourceFileDir = "D:\Download"
$cassandraFileName = "apache-cassandra-3.11.4-bin.tar.gz"
$janusgraphFileName = "janusgraph-0.4.1-hadoop2.zip"
$winRarFileName = "winutils.exe"
$graphexFileName = "graphexp.zip"
########********************************************************########

$esDir = $targetFileDir + '\janusgraph-0.4.1*\elasticsearch'
$cassandraDir = $targetFileDir + '\apache-cassandra-*'
$janusgraphDir = $targetFileDir + '\janusgraph-0.4.1*'
$janusgraphBinDir = $janusgraphDir + "\bin"
$cassandraConfDir = $cassandraDir + "\conf"
$gremlinServerConfDir = $janusgraphDir + "\conf\gremlin-server"
$graphex = $targetFileDir + "\" + 'graphexp'


# 解压文件，修改配置文件
function unpackFile() {
    # 解压缩文件
    cd $sourceFileDir
    tar -zxvf $cassandraFileName -C $targetFileDir
    Expand-Archive -Path $janusgraphFileName -DestinationPath $targetFileDir -Force
    Expand-Archive -Path $graphexFileName -DestinationPath $targetFileDir -Force

    cd $janusgraphBinDir
    Copy-Item $sourceFileDir"\"$winRarFileName .
}

function modifyConfigFile() {
    cd $janusgraphBinDir
    # 修改配置文件
    $file = 'gremlin-server.bat'
    $find = '-Dgremlin.io.kryoShimService=org.janusgraph.hadoop.serialize.JanusGraphKryoShimService'
    $replaceContent = '-Dgremlin.io.kryoShimService=org.janusgraph.hadoop.serialize.JanusGraphKryoShimService ^
 -Dfile.encoding=UTF-8'
    $isFindUTF8 = (Select-String "-Dfile.encoding=UTF-8" $file)
    if($isFindUTF8 -eq $null) {
        echo $file
        (Get-Content $file) -replace $find, $replaceContent | Set-Content $file
    }

    cd $cassandraConfDir
    $file = 'cassandra.yaml'
    $find = 'start_rpc: false'
    $replaceContent = 'start_rpc: true'
    (Get-Content $file -Raw) -replace $find, $replaceContent | Set-Content $file

    cd $gremlinServerConfDir
    $file = 'gremlin-server.yaml'
    $find1 = '{ className: org.apache.tinkerpop.gremlin.driver.ser.GryoMessageSerializerV1d0, config: { ioRegistries: \[org.janusgraph.graphdb.tinkerpop.JanusGraphIoRegistry\] }}'
    $replaceContent1 = '{ className: org.apache.tinkerpop.gremlin.driver.ser.GryoMessageSerializerV1d0, config: { ioRegistries: [org.apache.tinkerpop.gremlin.tinkergraph.structure.TinkerIoRegistryV1d0,org.janusgraph.graphdb.tinkerpop.JanusGraphIoRegistry] }}'
    $find2 = '{ className: org.apache.tinkerpop.gremlin.driver.ser.GryoMessageSerializerV3d0, config: { ioRegistries: \[org.janusgraph.graphdb.tinkerpop.JanusGraphIoRegistry\] }}'
    $replaceContent2 = '{ className: org.apache.tinkerpop.gremlin.driver.ser.GryoMessageSerializerV3d0, config: { ioRegistries: [org.apache.tinkerpop.gremlin.tinkergraph.structure.TinkerIoRegistryV3d0,org.janusgraph.graphdb.tinkerpop.JanusGraphIoRegistry] }}'
    $find3 = 'maxContentLength: 65536'
    $replaceContent3 = 'maxContentLength: 167772160'
    $find4 = 'scriptEvaluationTimeout: 30000'
    $replaceContent4 = 'scriptEvaluationTimeout: 29999999'
    (Get-Content $file -Raw) -replace $find1, $replaceContent1 | Set-Content $file
    (Get-Content $file -Raw) -replace $find2, $replaceContent2 | Set-Content $file
    (Get-Content $file) -replace $find3, $replaceContent3 | Set-Content $file
    (Get-Content $file) -replace $find4, $replaceContent4 | Set-Content $file
}

if($isDecomposeFile) {
    unpackFile
}

modifyConfigFile

# 启服务
cd $cassandraDir
Start-Process bin\cassandra.bat
cd $esDir
Start-Process bin\elasticsearch.bat
## 等待上面的服务启动
sleep 30
cd $janusgraphBinDir
Start-Process gremlin-server.bat

cd $graphex
Start-Process powershell.exe -ArgumentList { python -m SimpleHTTPServer }


