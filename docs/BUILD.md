# Build Full Setup

Requires Node.js and Windows with .NET Framework 4.8.
Clone this repository into a folder named `squad-hud`, then run the following commands from its parent directory.

1. Obtain UE4SS v4.0.0-6-gef15eba8 from the official UE4SS-RE/RE-UE4SS release.
2. Verify the downloaded archive SHA-256 is `26e2d523d241e27838448cf6407e9692643f3a550582840b60e8b07c47394df8`.
3. Place dwmapi.dll under squad-hud/work/loader/ and UE4SS.dll, UE4SS-settings.ini and LICENSE under squad-hud/work/loader/ue4ss/.
4. Use the exact UE4SS-settings.ini supplied in the source release (console, GUI console and hot reload disabled).
5. Run `powershell -File squad-hud/assets/build-icon.ps1`.
6. Run `node squad-hud/build.mjs`.
7. Run `squad-hud/outputs/Squad-Status-HUD-Setup.exe --self-test` (29 file ownership and installation assertions).

The output is squad-hud/outputs/Squad-Status-HUD-Setup.exe.
Lua files are loaded directly by UE4SS; no compilation is needed for the Nexus manual package.
The source release includes exact loader inputs and the Lua test harness for reproducibility.
