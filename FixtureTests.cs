using System;
using System.IO;
using System.Text;
using System.Linq;
public static class FixtureTests {
 static int count;
 static void Assert(bool value,string message){count++;if(!value)throw new Exception(message);}
 static void Reject(Action action,string message){bool failed=false;try{action();}catch{failed=true;}Assert(failed,message);}
 public static int Run(){string temp=Path.Combine(Path.GetTempPath(),"SquadHUD-fixture-"+Guid.NewGuid().ToString("N"));try{
  string steam=Path.Combine(temp,"steamapps"),game=Path.Combine(steam,@"common\StarshipTroopers_UltimateBugWar"),bin=Path.Combine(game,@"StarshipTroopers_UBW\Binaries\Win64");Directory.CreateDirectory(bin);File.WriteAllText(Path.Combine(game,"StarshipTroopers_UBW.exe"),"fixture");File.WriteAllText(Path.Combine(bin,"StarshipTroopers_UBW-Win64-Shipping.exe"),"fixture");File.WriteAllText(Path.Combine(steam,"appmanifest_2321780.acf"),"\"buildid\" \"22832378\"");var e=new Installer(game,true);var payload=e.Payload(false);string receipt=Path.Combine(bin,"SquadStatusHUD.install.json");
  e.Check(false);Assert(!File.Exists(receipt),"status is read-only");Assert(Encoding.UTF8.GetString(payload[Installer.Mod+"Scripts/config.lua"]).Contains("Language = \"en\""),"English default");Assert(Encoding.UTF8.GetString(e.Payload(true)[Installer.Mod+"Scripts/config.lua"]).Contains("Language = \"th\""),"optional Thai");
  string reshade=Path.Combine(bin,"dxgi.dll");File.WriteAllText(reshade,"ReShade fixture");
  e.Apply(false,false);foreach(var item in payload)Assert(Installer.Hash(File.ReadAllBytes(Path.Combine(bin,item.Key)))==Installer.Hash(item.Value),"fresh payload: "+item.Key);Assert(File.Exists(receipt),"receipt recorded");e.Apply(false,true);Assert(File.ReadAllText(Path.Combine(bin,Installer.Mod+"Scripts/config.lua")).Contains("Language = \"th\""),"language update");e.Apply(true,false);Assert(payload.Keys.All(k=>!File.Exists(Path.Combine(bin,k))),"owned payload removed");Assert(File.ReadAllText(reshade)=="ReShade fixture","ReShade untouched");
  string proxy=Path.Combine(bin,"dwmapi.dll");File.WriteAllText(proxy,"foreign");Reject(()=>e.Apply(false,false),"foreign loader blocked");Assert(File.ReadAllText(proxy)=="foreign","foreign loader retained");Assert(!File.Exists(receipt),"failed preflight no receipt");File.Delete(proxy);
  e.Fault=i=>{if(i==2)throw new Exception("injected fixture failure");};Reject(()=>e.Apply(false,false),"transaction fault caught");Assert(payload.Keys.All(k=>!File.Exists(Path.Combine(bin,k))),"fresh rollback complete");e.Fault=null;e.Apply(false,false);e.Fault=i=>{if(i==3)throw new Exception("injected removal failure");};Reject(()=>e.Apply(true,false),"removal fault caught");Assert(payload.All(x=>File.Exists(Path.Combine(bin,x.Key))&&Installer.Hash(File.ReadAllBytes(Path.Combine(bin,x.Key)))==Installer.Hash(x.Value)),"removal rollback complete");Assert(File.Exists(receipt),"receipt retained after rollback");e.Fault=null;
  string main=Path.Combine(bin,Installer.Mod+"Scripts/main.lua");File.AppendAllText(main,"-- changed");Reject(()=>e.Apply(true,false),"changed source retained");File.WriteAllBytes(main,payload[Installer.Mod+"Scripts/main.lua"]);
  string other=Path.Combine(bin,@"ue4ss\Mods\OtherMod\enabled.txt");Directory.CreateDirectory(Path.GetDirectoryName(other));File.WriteAllText(other,"");e.Apply(true,false);Assert(File.Exists(proxy),"shared loader retained for another mod");Assert(File.Exists(other),"other mod retained");Assert(!File.Exists(main),"own script removed with another mod present");
  // A pre-existing compatible loader must remain user-owned after another install/remove.
  e.Apply(false,false);e.Apply(true,false);Assert(File.Exists(proxy),"pre-existing loader retained");
  File.WriteAllText(Path.Combine(steam,"appmanifest_2321780.acf"),"\"buildid\" \"other\"");Reject(()=>e.Apply(false,false),"unsupported build blocked");
  Console.WriteLine("Fixture assertions passed: "+count);File.WriteAllText(Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"fixture-results.json"),"{\"passed\":true,\"assertions\":"+count+",\"game_modified\":false}");return 0;
 }catch(Exception ex){File.WriteAllText(Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"fixture-results.json"),"{\"passed\":false,\"error\":\""+ex.Message.Replace("\\","\\\\").Replace("\"","\\\"")+"\"}");return 1;}finally{string full=Path.GetFullPath(temp);if(full.StartsWith(Path.GetFullPath(Path.GetTempPath()),StringComparison.OrdinalIgnoreCase)&&Path.GetFileName(full).StartsWith("SquadHUD-fixture-"))Directory.Delete(full,true);}}
}
