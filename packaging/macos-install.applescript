-- Double-click installer on the SubDrop DMG (no Terminal commands for users).
on gatekeeper_help()
	set msg to "SubDrop was downloaded from the internet, so macOS may block it once. This is normal for free apps without an Apple Developer certificate." & return & return & "If you see “Apple could not verify Install SubDrop”:" & return & return & "1. Click Open Settings below." & return & "2. Scroll to Security and click Open Anyway for Install SubDrop." & return & "3. Double-click Install SubDrop again and confirm Open." & return & return & "Or right-click Install SubDrop → Open → Open."
	set choice to button returned of (display dialog msg buttons {"Open Settings", "Continue install"} default button 2 with title "One-time security step" with icon caution)
	if choice is "Open Settings" then
		try
			do shell script "open 'x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension'"
		on error
			try
				do shell script "open 'x-apple.systempreferences:com.apple.preference.security'"
			end try
		end try
	end if
end gatekeeper_help

on run
	gatekeeper_help()
	try
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

		display dialog "SubDrop is installed and opening now." & return & return & "Find it in Applications (in your home folder) or search Spotlight for SubDrop." buttons {"OK"} default button 1 with title "SubDrop" with icon note
	on error errMsg number errNum
		set helpMsg to "Install could not finish:" & return & errMsg & return & return & "If macOS blocked this app, use Open Settings in the first dialog, click Open Anyway, then run Install SubDrop again."
		set choice to button returned of (display dialog helpMsg buttons {"Open Settings", "OK"} default button 1 with title "SubDrop install" with icon stop)
		if choice is "Open Settings" then
			try
				do shell script "open 'x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension'"
			end try
		end if
	end try
end run
