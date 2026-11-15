import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {execFileSync} from 'node:child_process';
const base=path.resolve('squad-hud');
const payloads={
 'loader.proxy':'work/loader/dwmapi.dll',
 'loader.core':'work/loader/ue4ss/UE4SS.dll',
 'loader.settings':'work/loader/ue4ss/UE4SS-settings.ini',
 'loader.license':'work/loader/ue4ss/LICENSE',
 'mod.main':'mod/Scripts/main.lua',
 'mod.alerts':'mod/Scripts/alerts.lua',
 'mod.config':'mod/Scripts/config.lua',
 'mod.credits':'CREDITS.txt',
 'app.icon':'assets/Squad.ico',
 'app.image':'assets/Squad.png',
};
fs.mkdirSync(path.join(base,'outputs'),{recursive:true});
const args=['/nologo','/target:winexe','/optimize+','/platform:anycpu','/win32icon:'+path.join(base,'assets/Squad.ico'),'/reference:System.Windows.Forms.dll','/reference:System.Drawing.dll','/reference:System.Web.Extensions.dll'];
for(const [name,file] of Object.entries(payloads))args.push('/resource:'+path.join(base,file)+','+name);
const output=path.join(base,'outputs/Squad-Status-HUD-1.1.0-Setup.exe');
args.push('/out:'+output,path.join(base,'Setup.cs'),path.join(base,'FixtureTests.cs'));
execFileSync('C:/Windows/Microsoft.NET/Framework64/v4.0.30319/csc.exe',args,{stdio:'inherit'});
const manifest={version:'1.1.0',file:output,bytes:fs.statSync(output).size,sha256:crypto.createHash('sha256').update(fs.readFileSync(output)).digest('hex'),runtime_tested:true,default_language:'en',optional_language:'th',dependencies_bundled:['UE4SS v4.0.0-6-gef15eba8'],independent_of_thai_localization:true};
fs.writeFileSync(path.join(base,'work/build-manifest.json'),JSON.stringify(manifest,null,2)+'\n');
console.log(JSON.stringify(manifest,null,2));
