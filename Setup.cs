using System;
using System.IO;
using System.Linq;
using System.Text;
using System.Collections.Generic;
using System.Security.Cryptography;
using System.Reflection;
using System.Diagnostics;
using System.Drawing;
using System.Windows.Forms;
using System.Web.Script.Serialization;
[assembly: AssemblyTitle("Squad Status HUD Setup")]
[assembly: AssemblyCompany("NEXara")]
[assembly: AssemblyVersion("1.0.0.0")]
[assembly: AssemblyFileVersion("1.0.0.0")]

public class OwnedFile { public string Hash; public bool Owned; }
public class Receipt { public string Root,Version; public Dictionary<string,OwnedFile> Files=new Dictionary<string,OwnedFile>(); }
public class Installer {
 public const string Version="1.0.0";
 public const string Mod="ue4ss/Mods/SquadStatusHUD/";
 readonly string game,bin; readonly bool fixture;
 readonly JavaScriptSerializer json=new JavaScriptSerializer();
 public Action<int> Fault;
 public Installer(string root,bool test=false){game=Path.GetFullPath(root).TrimEnd(Path.DirectorySeparatorChar);bin=Path.Combine(game,@"StarshipTroopers_UBW\Binaries\Win64");fixture=test&&game.StartsWith(Path.GetTempPath(),StringComparison.OrdinalIgnoreCase)&&game.Contains("SquadHUD-fixture-");}
 public static string Hash(byte[] b){using(var s=SHA256.Create())return BitConverter.ToString(s.ComputeHash(b)).Replace("-","").ToLowerInvariant();}
 public static byte[] Resource(string n){using(var s=Assembly.GetExecutingAssembly().GetManifestResourceStream(n)){if(s==null)throw new Exception("Missing resource: "+n);using(var m=new MemoryStream()){s.CopyTo(m);return m.ToArray();}}}
 string At(string name){if(Path.IsPathRooted(name)||name.Split('/').Contains(".."))throw new Exception("Invalid payload path");string p=Path.GetFullPath(Path.Combine(bin,name.Replace('/',Path.DirectorySeparatorChar)));if(!p.StartsWith(bin+Path.DirectorySeparatorChar,StringComparison.OrdinalIgnoreCase))throw new Exception("Invalid destination");for(var d=new DirectoryInfo(Path.GetDirectoryName(p));d!=null;d=d.Parent)if(d.Exists&&(d.Attributes&FileAttributes.ReparsePoint)!=0)throw new Exception("Linked folders are not supported: "+d.FullName);if(File.Exists(p)&&(File.GetAttributes(p)&FileAttributes.ReparsePoint)!=0)throw new Exception("Linked files are not supported: "+p);return p;}
 string ReceiptPath {get{return At("SquadStatusHUD.install.json");}}
 Receipt ReadReceipt(){if(!File.Exists(ReceiptPath))return null;var r=json.Deserialize<Receipt>(File.ReadAllText(ReceiptPath));if(r==null||!string.Equals(r.Root,game,StringComparison.OrdinalIgnoreCase)||r.Files==null)throw new Exception("The install receipt does not match this game folder.");return r;}
 public Dictionary<string,byte[]> Payload(bool thai){return new Dictionary<string,byte[]>{
  {"dwmapi.dll",Resource("loader.proxy")},{"ue4ss/UE4SS.dll",Resource("loader.core")},
  {"ue4ss/UE4SS-settings.ini",Resource("loader.settings")},{"ue4ss/LICENSE",Resource("loader.license")},
  {Mod+"Scripts/main.lua",Resource("mod.main")},{Mod+"Scripts/config.lua",Encoding.UTF8.GetBytes(Encoding.UTF8.GetString(Resource("mod.config")).Replace("Language = \"en\"","Language = \""+(thai?"th":"en")+"\""))},
  {Mod+"enabled.txt",new byte[0]},{Mod+"CREDITS.txt",Resource("mod.credits")}};}
 void Closed(){if(fixture)return;foreach(var p in Process.GetProcesses()){using(p){if(p.ProcessName.StartsWith("StarshipTroopers_UBW",StringComparison.OrdinalIgnoreCase))throw new Exception("Close the game before installing or removing the mod. / กรุณาปิดเกมก่อน");}}}
 public string Check(bool removing){Closed();if(!File.Exists(Path.Combine(game,"StarshipTroopers_UBW.exe"))||!File.Exists(Path.Combine(bin,"StarshipTroopers_UBW-Win64-Shipping.exe")))throw new Exception("Select the game folder containing StarshipTroopers_UBW.exe. / เลือกโฟลเดอร์หลักของเกม");At("dwmapi.dll");if(!removing){string steam=Path.GetDirectoryName(Path.GetDirectoryName(game));string mf=Path.Combine(steam,"appmanifest_2321780.acf");if(!File.Exists(mf)||!System.Text.RegularExpressions.Regex.IsMatch(File.ReadAllText(mf),"\"buildid\"\\s+\"22832378\""))throw new Exception("This release supports Steam build 22832378 only.");}var r=ReadReceipt();return r==null?"Ready to install / พร้อมติดตั้ง":"Installed version / เวอร์ชันที่ติดตั้ง: "+r.Version;}
 bool OtherMods(){string path=Path.Combine(bin,@"ue4ss\Mods");if(!Directory.Exists(path))return false;return Directory.GetDirectories(path).Any(d=>!string.Equals(Path.GetFileName(d),"SquadStatusHUD",StringComparison.OrdinalIgnoreCase)&&!string.Equals(Path.GetFileName(d),"shared",StringComparison.OrdinalIgnoreCase));}
 public string Apply(bool remove,bool thai){Check(remove);var old=ReadReceipt();var payload=Payload(thai);var before=new Dictionary<string,byte[]>();var writes=new Dictionary<string,byte[]>();var next=new Receipt{Root=game,Version=Version};byte[] receiptBefore=File.Exists(ReceiptPath)?File.ReadAllBytes(ReceiptPath):null;
  if(remove&&old==null)return "Nothing to remove. / ยังไม่ได้ติดตั้ง";
  bool sharedNeeded=remove&&OtherMods();
  foreach(var item in payload){string name=item.Key,p=At(name);bool exists=File.Exists(p);byte[] content=exists?File.ReadAllBytes(p):null;OwnedFile known=null;if(old!=null)old.Files.TryGetValue(name,out known);
   if(remove){if(known==null||!known.Owned)continue;if(sharedNeeded&&!name.StartsWith(Mod,StringComparison.Ordinal))continue;if(!exists)continue;if(Hash(content)!=known.Hash)throw new Exception("File changed; kept untouched: "+name);writes[name]=null;}
   else if(exists){
    if(known!=null&&known.Owned){if(Hash(content)!=known.Hash)throw new Exception("File changed; kept untouched: "+name);writes[name]=item.Value;next.Files[name]=new OwnedFile{Hash=Hash(item.Value),Owned=true};}
    else if(Hash(content)==Hash(item.Value)||name=="ue4ss/UE4SS-settings.ini"||name=="ue4ss/LICENSE"){next.Files[name]=new OwnedFile{Hash=Hash(content),Owned=false};}
    else throw new Exception("Existing loader or mod file differs; nothing was replaced: "+name+". Use a clean compatible UE4SS installation.");
   }else{writes[name]=item.Value;next.Files[name]=new OwnedFile{Hash=Hash(item.Value),Owned=true};}
  }
  foreach(var item in writes)before[item.Key]=File.Exists(At(item.Key))?File.ReadAllBytes(At(item.Key)):null;
  try{int count=0;foreach(var item in writes){string p=At(item.Key);if(item.Value==null)File.Delete(p);else{Directory.CreateDirectory(Path.GetDirectoryName(p));File.WriteAllBytes(p,item.Value);}if(Fault!=null)Fault(++count);}
   if(remove)File.Delete(ReceiptPath);else{Directory.CreateDirectory(bin);File.WriteAllText(ReceiptPath,json.Serialize(next),new UTF8Encoding(false));}
  }catch{foreach(var item in before){string p=At(item.Key);if(item.Value==null){if(File.Exists(p))File.Delete(p);}else{Directory.CreateDirectory(Path.GetDirectoryName(p));File.WriteAllBytes(p,item.Value);}}if(receiptBefore==null){if(File.Exists(ReceiptPath))File.Delete(ReceiptPath);}else File.WriteAllBytes(ReceiptPath,receiptBefore);throw;}
  return remove?(sharedNeeded?"Mod removed. Shared UE4SS loader retained for other mods. / ลบม็อดแล้ว เก็บตัวโหลดที่ม็อดอื่นใช้ไว้":"Mod removed. / ลบม็อดแล้ว"):("Installed "+Version+". Start the game normally. / ติดตั้งสำเร็จ เปิดเกมตามปกติ");
 }
}
public class SetupForm:Form {
 bool thai=false,busy=false;TextBox folder=new TextBox(),status=new TextBox();Button language=new Button(),browse=new Button(),install=new Button(),remove=new Button(),check=new Button(),info=new Button();Label title=new Label(),subtitle=new Label(),features=new Label(),pathLabel=new Label(),credit=new Label(),example=new Label();
 string T(string en,string th){return thai?th:en;}
 public SetupForm(){Text="Squad Status HUD — Setup "+Installer.Version;ClientSize=new Size(700,635);MinimumSize=new Size(716,674);StartPosition=FormStartPosition.CenterScreen;BackColor=Color.FromArgb(17,24,37);ForeColor=Color.FromArgb(233,239,248);Font=new Font("Segoe UI",10);AutoScaleMode=AutoScaleMode.Dpi;using(var stream=new MemoryStream(Installer.Resource("app.icon")))Icon=new Icon(stream);
  language.SetBounds(591,18,90,30);language.Anchor=AnchorStyles.Top|AnchorStyles.Right;language.Click+=(s,e)=>{thai=!thai;Translate();};
  title.SetBounds(78,23,490,36);title.Font=new Font("Segoe UI",19,FontStyle.Bold);title.Text="Squad Status HUD";
  subtitle.SetBounds(80,63,580,28);subtitle.ForeColor=Color.FromArgb(151,172,201);subtitle.Text="Starship Troopers: Ultimate Bug War!";
  features.SetBounds(24,110,650,110);features.Font=new Font("Segoe UI",11);
  pathLabel.SetBounds(24,232,600,25);folder.SetBounds(24,262,545,30);browse.SetBounds(580,260,100,32);browse.Click+=(s,e)=>{using(var d=new FolderBrowserDialog()){d.Description=T("Select the game's main folder","เลือกโฟลเดอร์หลักของเกม");if(Directory.Exists(folder.Text))d.SelectedPath=folder.Text;if(d.ShowDialog()==DialogResult.OK)folder.Text=d.SelectedPath;}};
  example.SetBounds(24,301,650,65);example.Font=new Font("Segoe UI",8.5f);example.ForeColor=Color.FromArgb(151,172,201);
  install.SetBounds(24,383,656,44);install.BackColor=Color.FromArgb(25,106,204);install.ForeColor=Color.White;install.FlatStyle=FlatStyle.Flat;install.Click+=(s,e)=>Run(false);
  remove.SetBounds(365,440,180,32);remove.Click+=(s,e)=>Run(true);
  check.SetBounds(24,440,145,32);check.Click+=(s,e)=>{try{status.Text=new Installer(folder.Text).Check(false);}catch(Exception ex){status.Text=ex.Message;}};
  info.SetBounds(181,440,170,32);info.Click+=(s,e)=>MessageBox.Show(T("Made with AI by NEXara.\nUE4SS by the UE4SS-RE team and contributors (MIT).\nOriginal game content belongs to its owners.\n\nRelease 1.0.0 • Steam build 22832378.\nNo dependency on the Thai translation mod.\nLanguage switch also selects optional HUD labels for a new install.","Made with AI by NEXara\nUE4SS โดยทีม UE4SS-RE และผู้ร่วมพัฒนา (MIT)\nเกมเป็นของเจ้าของสิทธิ์เดิม\n\nRelease 1.0.0 • Steam build 22832378\nไม่ต้องใช้ม็อดแปลไทย\nภาษาที่เลือกใช้กับข้อความเสริมบน HUD ตอนติดตั้งด้วย"),"Information / ข้อมูล",MessageBoxButtons.OK,MessageBoxIcon.Information);
  status.SetBounds(24,487,656,85);status.Multiline=true;status.ReadOnly=true;status.ScrollBars=ScrollBars.Vertical;status.BackColor=Color.White;
  credit.SetBounds(24,592,656,25);credit.ForeColor=Color.DimGray;credit.Text="Made with AI by NEXara  •  Release 1.0.0  •  15 November 2026 (15/11/2026)";
  var badge=new PictureBox{Bounds=new Rectangle(24,25,42,42),SizeMode=PictureBoxSizeMode.Zoom,Image=Image.FromStream(new MemoryStream(Installer.Resource("app.image")))};Controls.Add(badge);foreach(var b in new[]{language,browse,remove,check,info}){b.FlatStyle=FlatStyle.Flat;b.FlatAppearance.BorderColor=Color.FromArgb(64,83,111);b.BackColor=Color.FromArgb(28,40,59);b.ForeColor=Color.FromArgb(224,235,250);}foreach(var b in new[]{check,info,remove}){b.FlatAppearance.BorderSize=0;b.BackColor=BackColor;b.ForeColor=Color.FromArgb(112,177,255);}install.FlatAppearance.BorderSize=0;install.Font=new Font("Segoe UI",11,FontStyle.Bold);status.BorderStyle=BorderStyle.FixedSingle;status.BackColor=Color.FromArgb(23,33,49);status.ForeColor=Color.FromArgb(184,204,230);credit.Font=new Font("Segoe UI",8);credit.ForeColor=Color.FromArgb(151,172,201);Controls.AddRange(new Control[]{language,title,subtitle,features,pathLabel,folder,browse,install,remove,check,info,status,credit,example});folder.Text=Detect();Translate();
 }
 public void UseThai(){thai=true;Translate();}
 string Detect(){foreach(var drive in DriveInfo.GetDrives().Where(d=>d.IsReady)){foreach(string rel in new[]{@"SteamLibrary\steamapps\common\StarshipTroopers_UltimateBugWar",@"Program Files (x86)\Steam\steamapps\common\StarshipTroopers_UltimateBugWar"}){string p=Path.Combine(drive.RootDirectory.FullName,rel);if(File.Exists(Path.Combine(p,"StarshipTroopers_UBW.exe")))return p;}}return "";}
 void Translate(){language.Text=thai?"EN / ไทย":"EN / ไทย";features.Text=T("Squad names and live health above the minimap\nStandalone mod • Includes the required UE4SS loader\nNames and blue health bars • Steam build 22832378","รายชื่อและพลังชีวิตสมาชิกทีมเหนือแผนที่ย่อ\nม็อดแยกอิสระ • รวมตัวโหลด UE4SS ที่จำเป็น\nชื่อพร้อมแถบพลังชีวิตสีฟ้า • Steam build 22832378");example.Text=T("Example game folder (your drive may differ):\nN:\\SteamLibrary\\steamapps\\common\\StarshipTroopers_UltimateBugWar\nSelect this folder, then click Install / Update. Do not select the .exe file.","ตัวอย่างโฟลเดอร์เกม (ไดรฟ์และตำแหน่งอาจต่างกัน):\nN:\\SteamLibrary\\steamapps\\common\\StarshipTroopers_UltimateBugWar\nเลือกโฟลเดอร์นี้ แล้วกดติดตั้ง / อัปเดต ไม่ต้องเลือกไฟล์ .exe");pathLabel.Text=T("Game folder","โฟลเดอร์เกม");browse.Text=T("Browse…","เลือกเกม…");install.Text=T("Install / Update","ติดตั้ง / อัปเดต");remove.Text=T("Uninstall","ถอนการติดตั้ง");check.Text=T("Check status","ตรวจสถานะ");info.Text=T("ⓘ Info & credits","ⓘ Info / เครดิต");if(!busy)status.Text=T("Select your game folder, then click Install. Close the game first.","เลือกโฟลเดอร์เกมแล้วกดติดตั้ง กรุณาปิดเกมก่อน");}
 void Run(bool removing){if(busy)return;if(removing&&MessageBox.Show(T("Remove Squad Status HUD from this game folder?","ถอน Squad Status HUD จากโฟลเดอร์เกมนี้หรือไม่?"),"Squad Status HUD",MessageBoxButtons.YesNo,MessageBoxIcon.Question)!=DialogResult.Yes)return;busy=true;foreach(var b in new[]{install,remove,check,browse,language})b.Enabled=false;try{status.Text=new Installer(folder.Text).Apply(removing,thai);}catch(Exception ex){status.Text=ex.Message;}finally{busy=false;foreach(var b in new[]{install,remove,check,browse,language})b.Enabled=true;}}
}
public static class Program {
 [STAThread] public static int Main(string[] args){if(args.Length==1&&args[0]=="--self-test")return FixtureTests.Run();if(args.Length==2&&(args[0]=="--install"||args[0]=="--uninstall")){try{string result=new Installer(args[1]).Apply(args[0]=="--uninstall",false);File.WriteAllText(Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"install-result.json"),new JavaScriptSerializer().Serialize(new{success=true,message=result}));return 0;}catch(Exception ex){File.WriteAllText(Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"install-result.json"),new JavaScriptSerializer().Serialize(new{success=false,message=ex.Message}));return 1;}}Application.EnableVisualStyles();Application.SetCompatibleTextRenderingDefault(false);if(args.Length==2&&(args[0]=="--preview"||args[0]=="--preview-th")){using(var f=new SetupForm()){if(args[0]=="--preview-th")f.UseThai();f.ShowInTaskbar=false;f.Opacity=0;f.Show();Application.DoEvents();using(var b=new Bitmap(f.Width,f.Height)){f.DrawToBitmap(b,new Rectangle(Point.Empty,f.Size));b.Save(args[1]);}}return 0;}Application.Run(new SetupForm());return 0;}
}
