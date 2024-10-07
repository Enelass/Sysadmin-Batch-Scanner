@echo off
setlocal enabledelayedexpansion
:: This script is designed for Sys Admin to gather comprehensive information about a remote machine within a local network. Whether client (workstation) or server.
:: It prompts the user to enter the hostname or IP address of the remote machine and then performs several tasks:
::    pinging (ICMP) the machine to check reachability,
::    querying DHCP leases to find the machine's DHCP records,
::    resolving DNS names and addresses,
::    retrieving hardware information using WMI,
::    scanning the operating system details,
::    identifying connected users,
::    and optionally performing an Nmap scan if Nmap is installed.
::    The script loops, allowing the user to scan multiple machines sequentially.
::
:: Tested on: 		Microsoft Windows 7, 8.1, 10
:: Requirements:	Nmap and RSAT, and Domain & Workstation Admin credentials
::					/!\ You need to set the DHCP Ranges at line
:: Date:      		February 17, 2016
:: Author:	  		Florian Bidabe @Enelass (https://au.linkedin.com/in/bidabe)

:: Set the domain controller variable
set DC=<Internal Domain Controller IP or FQDN>
set DNS_Name=<Internal DNS Server Name>
set DNS_Name=<Internal DNS Server IP address>
set DHCP_Range_SYD1=<10.16.10.0>
set DHCP_Range_WiFi=<10.17.20.0>
::set DHCP_Range_SYD2= 
::set DHCP_Range_MEL=


:Loop
cls
echo Scanning Remote Host...
set /p Desktop="Please enter hostname or IP for the remote machine: "

echo.
echo.
::Pinging and resolving netbios name
ping -a %Desktop% -n 1 | findstr Pinging
ping %Desktop% -n 1 | findstr Reply

echo.
echo.
echo ---- DHCP Lease:
netsh dhcp server \\%DC% scope %DHCP_Range_SYD1% show clients 1  > nul 2> nul
if not %ERRORLEVEL% EQU 0 (
echo You need to install the Remote Server Administration Tools to get a DHCP listing !
echo open https://goo.gl/y8dN7z )

:: This section of the script is designed to query the DHCP server for lease information within specific IP address scopes
:: It first checks if it can successfully query the DHCP server for clients. If this check fails (ERRORLEVEL is not 0), it indicates that the Remote Server Administration Tools (RSAT) might not be installed or there is an issue with the DHCP server connection.
netsh dhcp server \\%DC% scope %DHCP_Range_SYD1% show clients 1  > nul 2> nul
if %ERRORLEVEL% EQU 0 (
:: Office in Sydney
::   netsh dhcp server \\%DC% scope %DHCP_Range_SYD2% show clients 1 | findstr /I ".*%Desktop%.*"
::   netsh dhcp server \\%DC% scope %DHCP_Range_SYD3% show clients 1 | findstr /I ".*%Desktop%.*"
:: Office in Melbourne
::   netsh dhcp server \\%DC% scope %DHCP_Range_MEL% show clients 1 | findstr /I ".*%Desktop%.*"
:: WiFi DHCP Range
netsh dhcp server \\%DC% scope %DHCP_Range_WiFi% show clients 1 | findstr /I ".*%Desktop%.*"

echo.
echo.
echo ---- DNS Resolution:
for /f "tokens=2 delims=:" %%f in ('nslookup %Desktop% 2^>nul ^| find "Name:" ^| findstr /v %DNS_Name%') do echo %%f
for /f "tokens=2 delims=:" %%f in ('nslookup %Desktop% 2^>nul ^| find "Address:" ^| findstr /v %DNS_IP%') do echo %%f

echo.
echo.
echo ---- Hardware:
wmic /node:"%Desktop%" csproduct get Vendor,Name,IdentifyingNumber

echo ---- OS Scan:
wmic /node:"%Desktop%" OS get Caption,BuildNumber,CSDVersion,OSArchitecture,lastbootuptime

echo ---- User Connected:
wmic /node:"%Desktop%" ComputerSystem get Username
if %ERRORLEVEL% EQU 0 (
for /f "tokens=2 delims=<>" %%a in ('wmic /node:"%Desktop%" ComputerSystem get Username   /format:htable^|find "hidden"') do set "userid=%%a"
for /f "tokens=2 delims=\" %%b in ("!userid!") do set "shortid=%%b"
dsquery.exe * -filter sAMAccountName=!shortid! | dsget user -upn -email -tel -display -disabled -acctexpires)

where nmap > nul 2> nul
if not %ERRORLEVEL% EQU 0 (
echo Nmap is not installed...
echo Install it to remotely scan this machine: https://nmap.org/download.html )
where nmap > nul 2> nul
if %ERRORLEVEL% EQU 0 (
echo.
echo.
echo Nmap Scan:
nmap -sS --top-ports 1000 -PS22,80,113,445,548,33334 -PA80,113,21000 -PU18000 -PN -n -T5 %Desktop%)
ping -n 10 0.0.0.0 > /nul

echo Scanning another machine ? (crtl+c to quit)
pause
goto :Loop