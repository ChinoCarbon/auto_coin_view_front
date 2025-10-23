@echo off
chcp 65001 >nul
echo ========================================
echo 项目打包和WinSCP部署脚本
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
echo [步骤5] 检查WinSCP...
where winscp.exe >nul 2>&1
if %errorlevel% neq 0 (
    echo [错误] 未检测到WinSCP，请先安装WinSCP
    echo 下载地址: https://winscp.net/eng/download.php
    pause
    exit /b 1
)

echo [完成] 检测到WinSCP

echo.
echo [步骤6] 创建WinSCP命令文件...

:: 创建WinSCP命令文件
echo option batch abort > winscp_commands.txt
echo option confirm off >> winscp_commands.txt
echo open root@43.160.248.61 >> winscp_commands.txt
echo cd /www/wwwroot >> winscp_commands.txt
echo rm coinfront >> winscp_commands.txt
echo mkdir coinfront >> winscp_commands.txt
echo cd coinfront >> winscp_commands.txt
echo lcd dist >> winscp_commands.txt
echo put * >> winscp_commands.txt
echo chmod 755 * >> winscp_commands.txt
echo close >> winscp_commands.txt
echo exit >> winscp_commands.txt

echo [完成] WinSCP命令文件已创建: winscp_commands.txt

echo.
echo [步骤7] 执行WinSCP上传...
winscp.exe /script=winscp_commands.txt

if %errorlevel% equ 0 (
    echo [成功] WinSCP上传完成！
) else (
    echo [错误] WinSCP上传失败，请检查网络连接和服务器权限
)

:: 清理临时文件
del winscp_commands.txt 2>nul

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
