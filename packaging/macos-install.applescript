-- Runs only after macOS has allowed Install SubDrop (see READ FIRST.html on the DMG).

on run_install()
	set installerPOSIX to POSIX path of (path to me)
	if installerPOSIX ends with "/" then
		set installerPOSIX to text 1 thru -2 of installerPOSIX
	end if
	set dmgRoot to do shell script "dirname " & quoted form of installerPOSIX
	set srcApp to dmgRoot & "/SubDrop.app"
	set homeApps to (POSIX path of (path to home folder)) & "Applications"
	set dstApp to homeApps & "/SubDrop.app"

	do shell script "test -d " & quoted form of srcApp
	do shell script "mkdir -p " & quoted form of homeApps
	do shell script "rm -rf " & quoted form of dstApp & " && ditto " & quoted form of srcApp & " " & quoted form of dstApp
	do shell script "xattr -cr " & quoted form of dstApp
	do shell script "codesign --force --deep --sign - " & quoted form of dstApp & " 2>/dev/null || true"
end run_install

on run
	set msg to "Click Install SubDrop to copy the app to your Applications folder and remove the “damaged app” quarantine." & return & return & "If you have not allowed Install SubDrop in System Settings yet, close this window and follow READ FIRST.html on this disk first:" & return & return & "  Install SubDrop  →  Privacy & Security  →  Open Anyway" & return & return & "After installing, open SubDrop from Applications (in your home folder). We do not auto-launch it, so macOS stays responsive."
	set choice to button returned of (display dialog msg buttons {"Cancel", "Install SubDrop"} default button 2 cancel button 1 with title "Install SubDrop" with icon note)
	if choice is "Cancel" then
		return
	end if
	try
		run_install()
		display dialog "SubDrop is installed." & return & return & "Open it from Applications in your home folder, or search Spotlight for SubDrop." buttons {"OK"} default button 1 with title "Install SubDrop" with icon note
	on error errMsg number errNum
		display dialog "Install could not finish:" & return & errMsg & return & return & "If Install SubDrop was blocked, use READ FIRST.html on this disk:" & return & "  Install SubDrop  →  Privacy & Security  →  Open Anyway" buttons {"OK"} default button 1 with title "Install SubDrop" with icon stop
	end try
end run
