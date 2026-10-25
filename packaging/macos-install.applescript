-- Double-click installer on the SubDrop DMG (no Terminal commands for users).
on run
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

		display dialog "SubDrop is installed and opening now." & return & return & "You can open it again from Applications in your home folder, or search Spotlight for SubDrop." buttons {"OK"} default button 1 with title "SubDrop" with icon note
	on error errMsg number errNum
		display dialog errMsg & return & return & "Try right-clicking Install SubDrop, choose Open, then run this installer again." buttons {"OK"} default button 1 with title "SubDrop install failed" with icon stop
	end try
end run
