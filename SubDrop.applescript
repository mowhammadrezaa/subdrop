-- SubDrop: drop videos (or folders) to fetch subtitles beside each file.
property staysOpen : true

on run
	display notification "Drop video files or folders here." with title "SubDrop"
end run

on open theItems
	set bundlePOSIX to POSIX path of (path to me)
	if bundlePOSIX ends with "/" then
		set bundlePOSIX to text 1 thru -2 of bundlePOSIX
	end if
	set fetchSh to bundlePOSIX & "/Contents/Resources/fetch.sh"

	repeat with anItem in theItems
		set itemPath to POSIX path of anItem
		try
			do shell script quoted form of fetchSh & " " & quoted form of itemPath
		on error errMsg number errNum
			display notification errMsg with title "SubDrop error"
		end try
	end repeat
end open
