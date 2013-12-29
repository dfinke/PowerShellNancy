param($port = 1234)

function Clear-Nancy {
    del nancy* -Recurse -Force
    del .\Program.exe
}


function Get-NancyDlls {
    if(! (Get-Command nuget.exe -ErrorAction SilentlyContinue) ) {
        "You need to install NuGet"
        start "http://nuget.codeplex.com/"

        return
    }

    if(dir nancy* -Directory) { return } 

    nuget install nancy
    nuget install nancy.hosting.self

    dir Nancy* -Directory |
        ForEach {
            Dir $_ -Recurse *.dll | Copy-Item -Verbose
        }
}

Get-NancyDlls

$NancyCode = @"
using System;
using Nancy;
using Nancy.Hosting.Self;

class Program
{
    static void Main()
    {
        Nancy.StaticConfiguration.DisableErrorTraces = false;
        using (var host = 
            new NancyHost(new Uri("http://localhost:$($port)"))
        )
        {
            host.Start();
            Console.ReadLine();
        }
    }
}

public class PowerShellModule : NancyModule
{
    public PowerShellModule()
    {
        Get["/"] = _ => @"'[{0}] Nancy Welcomes PowerShell!'-f `
            (Get-Date)".InvokePowerShell();
        
        Get["/ps"]       = _ => 
          @"Get-Process | 
             Select Name, Company, Handles | 
             ConvertTo-Json".InvokePowerShell();
        
        Get["/psHtml"]   = _ => 
          @"Get-Process |
            Select Name, Company, Handles | 
            ConvertTo-Html".InvokePowerShell();
        
        Get["/gsv"]      = _ => 
          @"Get-Service | 
            Select Name, Status | 
            ConvertTo-Json".InvokePowerShell();

        Get["/gsvHtml"]  = _ => 
          @"Get-Service | 
            Select Name, Status | 
            ConvertTo-Html".InvokePowerShell();

        Get["/psfile/{fileName}"] = x => {
            
            var targetFileName = x.fileName + ".ps1";
            
            if (System.IO.File.Exists(targetFileName))
            {
                return PowerShellExt.InvokePowerShell(
                    System.IO.File.ReadAllText(targetFileName)
                );
            }
            
            return string.Format("{0} not found", x.fileName);
        };

    }
}

public static class PowerShellExt
{
    public static object InvokePowerShell(this string script)
    {
        return System.Management.Automation.
           PowerShell.Create().
           AddScript(script).
           AddCommand("Out-String").
           Invoke()[0].ToString();
    }
}
"@

Add-Type `
    -TypeDefinition $NancyCode `
    -ReferencedAssemblies (Resolve-Path .\Nancy.dll), (Resolve-Path .\Nancy.Hosting.Self.dll), Microsoft.CSharp.dll `
    -OutputType ConsoleApplication `
    -OutputAssembly Program.exe

if(!$?) { return }

start http://localhost:$port/ps
start http://localhost:$port/psHtml
start http://localhost:$port/gsv
start http://localhost:$port/gsvHtml
start http://localhost:$port/psfile/test
start http://localhost:$port

"Running at http://localhost:$port"

.\Program.exe