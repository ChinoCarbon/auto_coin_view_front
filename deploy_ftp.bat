@echo off
chcp 65001 >nul
echo ========================================
echo 项目打包和FTP部署脚本
echo ========================================

:: 设置颜色
color 0A

:: 检查Node.js是否安装
node --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [错误] 未检测到Node.js，请先安装Node.js
    pause
    exit /b 1
)

echo [信息] 检测到Node.js版本:
node --version

echo.
echo [步骤1] 清理旧的构建文件...
if exist "dist" (
    rmdir /s /q "dist"
    echo [完成] 已清理旧的dist文件夹
) else (
    echo [信息] dist文件夹不存在，跳过清理
)

echo.
echo [步骤2] 安装依赖...
call npm install
if %errorlevel% neq 0 (
    echo [错误] 依赖安装失败
    pause
    exit /b 1
)
echo [完成] 依赖安装成功

echo.
echo [步骤3] 构建项目...
call npm run build
if %errorlevel% neq 0 (
    echo [错误] 项目构建失败
    pause
    exit /b 1
)
echo [完成] 项目构建成功

echo.
echo [步骤4] 检查构建文件...
if not exist "dist" (
    echo [错误] dist文件夹不存在，构建可能失败
    pause
    exit /b 1
)

:: 统计构建文件
for /f %%i in ('dir /b /a-d "dist" 2^>nul ^| find /c /v ""') do set fileCount=%%i
echo [信息] 构建完成，共生成 %fileCount% 个文件

echo.
echo [步骤5] 创建FTP上传脚本...

:: 创建FTP命令文件
echo open 43.160.248.61 > ftp_commands.txt
echo user root >> ftp_commands.txt
echo binary >> ftp_commands.txt
echo cd /www/wwwroot >> ftp_commands.txt
echo rm coinfront >> ftp_commands.txt
echo mkdir coinfront >> ftp_commands.txt
echo cd coinfront >> ftp_commands.txt
echo lcd dist >> ftp_commands.txt
echo mput * >> ftp_commands.txt
echo quit >> ftp_commands.txt

echo [完成] FTP命令文件已创建: ftp_commands.txt

echo.
echo [步骤6] 准备FTP上传...
echo 请确保您有服务器的FTP访问权限
echo 服务器: 43.160.248.61
echo 用户名: root
echo 目标路径: /www/wwwroot/coinfront
echo.
echo 按任意键开始FTP上传...
pause

echo.
echo [步骤7] 执行FTP上传...
ftp -s:ftp_commands.txt

if %errorlevel% equ 0 (
    echo [成功] FTP上传完成！
) else (
    echo [错误] FTP上传失败，请检查网络连接和服务器权限
)

:: 清理临时文件
del ftp_commands.txt 2>nul

echo.
echo ========================================
echo 部署完成！
echo ========================================
echo 网站地址: http://43.160.248.61/coinfront
echo 服务器路径: /www/wwwroot/coinfront
echo ========================================
echo.
echo 按任意键退出...
pause >nul
