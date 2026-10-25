-- Double-click installer on the SubDrop DMG (no Terminal commands for users).

on open_privacy_settings()
	try
		do shell script "open 'x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension'"
	on error
		try
			do shell script "open 'x-apple.systempreferences:com.apple.preference.security'"
		end try
	end try
end open_privacy_settings

on installer_welcome()
	set msg to "This installs SubDrop on your Mac (UTF-8 subtitles beside your videos)." & return & return & "If macOS says Apple could not verify Install SubDrop (common for free downloads), do this once:" & return & return & "  1. Install SubDrop  →  Privacy & Security  →  Open Anyway" & return & return & "  2. Double-click Install SubDrop again, then click Open." & return & return & "Tip: click Open Privacy & Security below, scroll to Security, then choose Open Anyway for Install SubDrop." & return & return & "When that is done (or if macOS did not block you), click Install SubDrop."
	set choice to button returned of (display dialog msg buttons {"Open Privacy & Security", "Install SubDrop", "Cancel"} default button 2 cancel button 3 with title "Install SubDrop" with icon note)
	return choice
end installer_welcome

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
	do shell script "open " & quoted form of dstApp

	display dialog "SubDrop is installed and opening now." & return & return & "Find it in Applications (in your home folder) or search Spotlight for SubDrop." buttons {"OK"} default button 1 with title "Install SubDrop" with icon note
end run_install

on run
	set choice to installer_welcome()
	if choice is "Cancel" then
		return
	end if
	if choice is "Open Privacy & Security" then
		open_privacy_settings()
		return
	end if
	try
		run_install()
	on error errMsg number errNum
		set helpMsg to "Install could not finish:" & return & errMsg & return & return & "If macOS blocked Install SubDrop:" & return & return & "  Install SubDrop  →  Privacy & Security  →  Open Anyway" & return & return & "Then double-click Install SubDrop again."
		set choice2 to button returned of (display dialog helpMsg buttons {"Open Privacy & Security", "OK"} default button 1 with title "Install SubDrop" with icon stop)
		if choice2 is "Open Privacy & Security" then
			open_privacy_settings()
		end if
	end try
end run
