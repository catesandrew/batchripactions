#!/usr/bin/env sh

# main.command
# Batch Rip

#  Created by Robert Yamada on 10/5/09.
#  Revisions: 20091024 ###
#	20091027: Added arg for Fairmount path.
#	20091028: Fixed bdRom typo in sed statement.
#   20091117: Added support for Batch Rip Dispatcher.
#   20091118: Added AS to change appearance of Terminal Session.
#   20091120: Added back support for skipping duplicates
#   20091201: Finally got around to adding subroutine to pass variables as args to shell
#   20091203: Removed "&" from end of runScript call
#   20091203: Changed runScript again batchEncode was finishing early
#   20101206: Added support for renaming disc copies
#   20101209: Changed to much to list

#  Copyright (c) 2009-2010 Robert Yamada
#	This program is free software: you can redistribute it and/or modify
#	it under the terms of the GNU General Public License as published by
#	the Free Software Foundation, either version 3 of the License, or
#	(at your option) any later version.

#	This program is distributed in the hope that it will be useful,
#	but WITHOUT ANY WARRANTY; without even the implied warranty of
#	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#	GNU General Public License for more details.

#	You should have received a copy of the GNU General Public License
#	along with this program.  If not, see <http://www.gnu.org/licenses/>.


function appleScriptDialogVideoKind () {
	cat << EOF | osascript -l AppleScript
		-- BLU-RAY LAUNCH BATCH RIP
		-- CANCEL AFTER 30 SECONDS OF NO INPUT
tell application "Automator Runner"
	activate
	display dialog "$2" & " Detected: " & return & "$1" & return & "Select a video kind to continue." buttons {"Ignore", "TV Show", "Movie"} default button 1 giving up after 30 with icon 0
	if the button returned of the result is "Ignore" then
		return "Cancel"
	else if the button returned of the result is "Movie" then
		return "Movie"
	else if the button returned of the result is "TV Show" then
		return "TV Show"
	else
		return "Cancel"
	end if
end tell
EOF
}

function displayDialogGetMovieName () {
	cat << EOF | osascript -l AppleScript
		set theFile to "$1"
		set theName to "$2"
		set theType to "$3"
		tell application "Automator Runner" 
		activate
		display dialog "What is the" & space & theType & space & "title you'd like to search for?" & return & "Disc: " & TheFile default answer theName buttons {"Skip", "Search"} default button 2 giving up after 30
		copy the result as list to {button_pressed, text_returned}
		if the button_pressed is "Search" then
		return text_returned
		else
		return "Skip"
		end if
		end tell
EOF
}

function tmdbGetMovieTitles () {
#	discNameNoYear=`echo "$1" | sed -e 's|\ (.*||g' -e 's|\ \-\ |:\ |g' -e 's|\&|\&amp;|g'`
	discNameNoYear=`echo "$1" | sed -e 's|\ (.*||g' -e 's|\ \-\ |:\ |g'`
	# set TMDb searchTerm
	searchTerm=`echo "$discNameNoYear" | sed -e 's|\ |+|g' -e "s|\'|%27|g"`
	movieYear=`echo "$1" | awk -F\( '{print $2}' | awk -F\) '{print $1}'`
	curl -s "http://api.themoviedb.org/2.1/Movie.search/en/xml/8d7d0edf7ec73435ea5d99d9cba9b54d/$searchTerm" > "${tmpFolder}/${searchTerm}.xml"
	tmdbSearch=`cat "${tmpFolder}/${searchTerm}.xml" | grep '<id>' | awk -F\> '{print $2}' | awk -F\< '{print $1}'`

	for tmdbID in $tmdbSearch
	do
		# download each id to tmp.xml
		curl -s "http://api.themoviedb.org/2.1/Movie.getInfo/en/xml/8d7d0edf7ec73435ea5d99d9cba9b54d/$tmdbID" > "${tmpFolder}/${searchTerm}-${tmdbID}.xml"
		movieData="${tmpFolder}/${searchTerm}-${tmdbID}.xml"
		releaseDate=`cat "$movieData" | grep '<released>' | awk -F\> '{print $2}' | awk -F\< {'print $1'} | sed 's|-.*||g'`
		# get movie title
		movieTitle=`substituteISO88591 "$(cat "$movieData" | grep '<name>' | awk -F\> '{print $2}' | awk -F\< {'print $1'} | sed -e "s|&apos;|\'|g" -e 's|:| -|g' -e "s|&amp;|\&|g")"`

		moviesFound="${moviesFound}${movieTitle} (${releaseDate})+"

	done
	echo $moviesFound | tr '+' '\n'
}

function tvdbGetSeriesTitles () {
#	discNameNoYear=`echo "$1" | sed -e 's|\ (.*||g' -e 's|\ \-\ |:\ |g' -e 's|\&|\&amp;|g'`
	# set TVdb searchTerm
	searchTerm=$(echo "$1" | sed -e 's|\ |+|g' -e 's|\ \-\ |:\ |g' -e "s|\'|%27|g")
	# get mirror URL
	tvdbMirror=`curl -s "http://www.thetvdb.com/api/9F21AC232F30F34D/mirrors.xml" | "$xpathPath" //mirrorpath 2>/dev/null | awk -F\> '{print $2}' | awk -F\< '{print $1}'`
	#get series id
	curl -s "$tvdbMirror/api/GetSeries.php?seriesname=$searchTerm" > "${tmpFolder}/${searchTerm}.xml"
	tvdbSearch=`cat "${tmpFolder}/${searchTerm}.xml" | grep '<id>' | awk -F\> '{print $2}' | awk -F\< '{print $1}'`
	for tvdbID in $tvdbSearch
	do
		# download each id to tmp.xml
		curl -s "$tvdbMirror/api/9F21AC232F30F34D/series/$tvdbID/en.xml" > "${tmpFolder}/${searchTerm}-${tvdbID}.xml"
		seriesData="${tmpFolder}/${searchTerm}-${tvdbID}.xml"
		dateAired=`cat "$seriesData" | grep '<FirstAired>' | awk -F\> '{print $2}' | awk -F\< {'print $1'} | sed 's|-.*||g'`
		# get movie title
		seriesTitle=`substituteISO88591 "$(cat "$seriesData" | grep '<SeriesName>' | awk -F\> '{print $2}' | awk -F\< {'print $1'} | sed -e "s|&apos;|\'|g" -e 's|:| -|g' -e "s|&amp;|\&|g")"`

		if [ ! -z "$seriesTitle" ]; then
			seriesFound="${seriesFound}${seriesTitle} - First Aired: ${dateAired}+"
		fi
	done
		echo $seriesFound | tr '+' '\n'
}

function displayDialogChooseTitle () {
	cat << EOF | osascript -l AppleScript
	try
		set theList to paragraphs of "$1"
		with timeout of 30 seconds
			tell application "Automator Runner" 
				activate
				choose from list theList with title "Choose from List" with prompt "Please make your selection:"
				end tell
		end timeout
	on error
		tell application "System Events" to key code 53
		set result to false
	end try
EOF
}

function displayDialogGetSeasonAndDisc () {
	cat << EOF | osascript -l AppleScript
		set theFile to "$2"
		tell application "Automator Runner" 
		activate
		display dialog "Enter Season & Disc Number for " & theFile default answer "S1D1" buttons {"Cancel", "OK"} default button 2 giving up after 30
		copy the result as list to {button_pressed, text_returned}
		if the button_pressed is "OK" then
		return text_returned
		else
		return "Cancelled"
		end if
		end tell
EOF
}

function substituteISO88591 () {
	returnString=`echo "$1" | sed -e 's|&#162;| cents|g' -e 's|&#163;|#|g' -e 's|&#164;|$|g' -e 's|&#165;| yen|g' -e 's|&#169;|©|g' -e 's|&#171;|"|g' -e 's|&#172;|/|g' -e 's|&#173;|-|g' -e 's|&#174;|¨|g' -e 's|&#176;|¼|g' -e 's|&#177;|+/-|g' -e 's|&#178;| 2|g' -e 's|&#179;| 3|g' -e 's|&#180;|^|g' -e 's|&#181;||g' -e 's|&#182;|¦|g' -e 's|&#183;|,|g' -e 's|&#184;||g' -e 's|&#185;| 1|g' -e 's|&#186;||g' -e 's|&#187;|"|g' -e 's|&#188;|1/4|g' -e 's|&#189;|1/2|g' -e 's|&#190;|3/4|g' -e 's|&#191;|!|g' -e 's|&#192;|A|g' -e 's|&#193;|A|g' -e 's|&#194;|A|g' -e 's|&#195;|A|g' -e 's|&#196;|A|g' -e 's|&#197;|A|g' -e 's|&#198;|AE|g' -e 's|&#199;|C|g' -e 's|&#200;|E|g' -e 's|&#201;|E|g' -e 's|&#202;|E|g' -e 's|&#203;|E|g' -e 's|&#204;|I|g' -e 's|&#205;|I|g' -e 's|&#206;|I|g' -e 's|&#207;|I|g' -e 's|&#208;|TH|g' -e 's|&#209;|N|g' -e 's|&#210;|O|g' -e 's|&#211;|O|g' -e 's|&#212;|O|g' -e 's|&#213;|O|g' -e 's|&#214;|O|g' -e 's|&#215;|x|g' -e 's|&#216;|O|g' -e 's|&#217;|U|g' -e 's|&#218;|U|g' -e 's|&#219;|U|g' -e 's|&#220;|U|g' -e 's|&#221;|Y|g' -e 's|&#222;||g' -e 's|&#223;|s|g' -e 's|&#224;|a|g' -e 's|&#225;|a|g' -e 's|&#226;|a|g' -e 's|&#227;|a|g' -e 's|&#228;|a|g' -e 's|&#229;|a|g' -e 's|&#230;|ae|g' -e 's|&#231;|c|g' -e 's|&#232;|e|g' -e 's|&#233;|e|g' -e 's|&#234;|e|g' -e 's|&#235;|e|g' -e 's|&#236;|i|g' -e 's|&#237;|i|g' -e 's|&#238;|i|g' -e 's|&#239;|i|g' -e 's|&#240;|th|g' -e 's|&#241;|n|g' -e 's|&#242;|o|g' -e 's|&#243;|o|g' -e 's|&#244;|o|g' -e 's|&#245;|o|g' -e 's|&#246;|o|g' -e 's|&#247;||g' -e 's|&#248;|o|g' -e 's|&#249;|u|g' -e 's|&#250;|u|g' -e 's|&#251;|u|g' -e 's|&#252;|u|g' -e 's|&#253;|y|g' -e 's|&#254;||g' -e 's|&#255;|y|g' -e 's|&#34;|?|g' -e 's|&#38;|&|g' -e 's|&#60;|<|g' -e 's|&#62;|>|g' -e 's|&#338;|OE|g' -e 's|&#339;|oe|g' -e 's|&#352;|S|g' -e 's|&#353;|s|g' -e 's|&#376;|Y|g' -e 's|&#382;|z|g' -e 's|&#710;||g' -e 's|&#732;|~|g' -e 's|&#8194;| |g' -e 's|&#8195;| |g' -e 's|&#8201;| |g' -e 's|&#8204;||g' -e 's|&#8205;||g' -e 's|&#8206;||g' -e 's|&#8207;||g' -e 's|&#8211;|-|g' -e 's|&#8212;|-|g' -e "s|&#8216;|'|g" -e "s|&#8217;|'|g" -e "s|&#8218;|'|g" -e 's|&#8220;|"|g' -e 's|&#8221;|"|g' -e 's|&#8222;|"|g' -e 's|&#8224;||g' -e 's|&#8225;||g' -e 's|&#8240;||g' -e 's|&#8249;|<|g' -e 's|&#8250;|>|g' -e 's|&#8364;|e|g'`
	echo "$returnString"
}

function runScript () {
		scriptTmpPath="$HOME/Library/Application Support/Batch Rip/batchRipTmp.sh"
		echo "\"$1\" \"$2\"" > "$scriptTmpPath"
		chmod 777 "$scriptTmpPath"
		open -a Terminal "$scriptTmpPath"
}

function appleScriptDialogContinue () {
	cat << EOF | osascript -l AppleScript
		-- BLU-RAY LAUNCH BATCH RIP
		-- CANCEL AFTER 30 SECONDS OF NO INPUT
tell application "Automator Runner"
	activate
	display dialog "Batch Rip Dispatcher: " & "Disc Detected." & return & "Waiting for next disc. Click Continue when ready." buttons {"Cancel", "Ignore All", "Continue"} default button 3 giving up after 120 with icon 0
	if the button returned of the result is "Cancel" then
		return "Cancel"
	else if the button returned of the result is "Ignore All" then
		return "Ignore"
	else if the button returned of the result is "Continue" then
		return "Continue"
	else
		return "Cancel"
	end if
end tell
EOF
}

function appleScriptError () {
	osascript -e 'tell application "Automator Runner"' -e 'activate' -e 'display alert "Error: Batch Rip no titles found" message "Error: The API server did not return any titles matching your search term; or the API your trying to search may be down." & Return & Return & "The action will continue, but you will have to rename the copies after the action has finished."' -e 'end tell'
}

# variables
xpathPath="/usr/bin/xpath"
scriptPID=$$
currentItemsList="$HOME/Library/Application Support/Batch Rip/currentItems.txt"

# create action temp folder
tmpFolder="/tmp/batchRipLauncher-${scriptPID}"
if [ ! -e "$tmpFolder" ]; then
	mkdir "$tmpFolder"
fi

# Make batchRip folder
if [ ! -d "$HOME/Library/Application Support/Batch Rip" ]; then
	mkdir "$HOME/Library/Application Support/Batch Rip"
fi

# multi-disc prompt
if [[ ! "${autoRun}" ]]; then autoRun=0; fi
	# Get current state of Batch Rip Dispatch LaunchAgent; if enabled continue.
	currentState=`launchctl list com.batchRip.BatchRipDispatcher 2> /dev/null`
	if [ ! -z "$currentState" ]; then
		# Get count of optical drives
		deviceCount=`ioreg -iSr -w 0 -c IODVDBlockStorageDevice | grep "Device Characteristics" | sed -e 's|.*"Product Name"="||' -e 's|".*||' | grep -c ""`
		if [[ deviceCount -gt 1 && "$autoRun" -eq 0 ]]; then
		launchAction=`appleScriptDialogContinue`
		if [[ "$launchAction" = "Cancel" || -z "$launchAction" ]]; then
			if [ -d "$tmpFolder" ]; then
				rm -rf $tmpFolder
			fi
			exit 0
		elif [[ "$launchAction" = "Ignore" ]]; then
			df -T udf | grep "Volumes" | awk -F\ / {'print $2'} | sed -e 's|^|\/|g' -e 's|$|:Ignore|g' > "$currentItemsList"
			if [ -d "$tmpFolder" ]; then
				rm -rf $tmpFolder
			fi
			exit 0
		fi
	fi
fi
if [ -e "$currentItemsList" ]; then
	rm -f "$currentItemsList"
fi

input=`cat`

if [ ! -z "$input" ]; then
	input=`echo "$input" | tr ' ' '\007'`
else
	input=`df -T udf | grep "Volumes" | awk -F\ / {'print $2'} | sed 's|^|\/|g' | tr ' ' '\007' | sort -f`
fi

for eachItem in $input
do
	eachItem=`echo "$eachItem" | tr '\007' ' '`
	itemCount=$((itemCount + 1))
done

processDisc=0
for thePath in $input
do
	thePath=`echo "$thePath" | tr '\007' ' '`
	# Check disc type and set variables
	discType=`diskutil info "$thePath" | grep "Optical Media Type" | sed 's|.*: *||'`
	if [[ "$discType" = "BD-ROM" && bdRom -eq 1 || "$discType" = "DVD-ROM" && dvdRom -eq 1 ]]; then
		if [[ ! "${skipDuplicates}" ]]; then skipDuplicates=0; fi
		if [[ ! "${autoRun}" ]]; then autoRun=0; fi
		if [[ ! "${saveLog}" ]]; then saveLog=0; fi
		if [[ ! "${bdRom}" ]]; then bdRom=0; fi
		if [[ ! "${dvdRom}" ]]; then dvdRom=0; fi
		if [[ ! "${growlMe}" ]]; then growlMe=0; fi
		if [[ ! "${useOnlyMakeMKV}" ]]; then useOnlyMakeMKV=0; fi
		if [[ ! "${ejectDisc}" ]]; then ejectDisc=0; fi
		if [[ ! "${scriptPath}" ]]; then scriptPath=""; fi
		if [[ ! "${tvPath}" ]]; then tvPath=""; fi
		if [[ ! "${moviePath}" ]]; then moviePath=""; fi
		if [[ ! "${fairmountPath}" ]]; then fairmountPath=""; fi
		if [[ ! "${makemkvPath}" ]]; then makemkvPath=""; fi
		if [[ ! "${videoKind}" ]]; then videoKind="0"; fi
		if [[ videoKind -eq 0 ]]; then videoKind="Movie"; fi
		if [[ videoKind -eq 1 ]]; then videoKind="TV Show"; fi
		if [[ ! "${tvMinTime}" ]]; then tvMinTime=0; fi
		if [[ ! "${tvMaxTime}" ]]; then tvMaxTime=0; fi
		if [[ ! "${movieMinTime}" ]]; then movieMinTime=0; fi
		if [[ ! "${movieMaxTime}" ]]; then movieMaxTime=0; fi
		if [[ ! "${discDelay}" ]]; then discDelay=20; fi
		if [[ ! "${copyDelay}" ]]; then copyDelay=20; fi
		if [[ ! "${fullBdBackup}" ]]; then fullBdBackup=0; fi
		if [[ ! "${renameDisc}" ]]; then renameDisc=1; fi
		
		# Set path to batchRip.sh
		scriptPath="$HOME/Library/Automator/Batch Rip.action/Contents/Resources/batchRip.sh"

		# Check if this disc is currently being processed
		bashPID=`ps uxc | grep -i "Bash" | awk '{print $2}'`
		for eachPID in $bashPID
		do
			if grep "$thePath" < /tmp/batchRip-$eachPID/currentItems.txt ; then
				continue
			fi
		done

		# Temporarily replace spaces in paths
		fairmountPath=`echo "$fairmountPath" | tr ' ' ':'`
		makemkvPath=`echo "$makemkvPath" | tr ' ' ':'`
		moviePath=`echo "$moviePath" | tr ' ' ':'`
		tvPath=`echo "$tvPath" | tr ' ' ':'`
		
		# Set scriptArgs
		scriptArgs="--skipDuplicates $skipDuplicates --encodeHdSources $bdRom --saveLog $saveLog --fairmountPath $fairmountPath --makemkvPath $makemkvPath --movieOutputDir $moviePath --tvOutputDir $tvPath --encodeDvdSources $dvdRom --growlMe $growlMe --onlyMakeMKV $useOnlyMakeMKV --ejectDisc $ejectDisc --minTrackTimeTV $tvMinTime --maxTrackTimeTV $tvMaxTime --minTrackTimeMovie $movieMinTime --maxTrackTimeMovie $movieMaxTime --discDelay $discDelay --copyDelay $copyDelay --fullBdBackup $fullBdBackup"
					
		# Process discs if set to not run automatically
		if [[ ! autoRun -eq 1 ]]; then

			# Get user input for action
			getVideoKind=`appleScriptDialogVideoKind "$thePath" "$discType"`
			
			# If video kind is returned, setup and launch batchRip. If ignore is returned, set to ignore.
			if [[ ! "$getVideoKind" = "Cancel" && ! -z "$getVideoKind" ]]; then
				videoKind="$getVideoKind"
				processDisc=1
				# If renameDisc is set to yes, get disc name from user input
				if [[ $renameDisc -eq 1 ]]; then
					# reset variables
					newDiscName=""
					theTitle=""
					theSeriesName=""
					nameWithSeasonAndDisc=""
					discName=`basename "$thePath" | tr '_' ' ' | sed 's| ([0-9]*)||'`
					getDiscName=`displayDialogGetMovieName "$thePath" "$discName" "$videoKind"`
					if [[ ! -z "$getDiscName" && ! "$getDiscName" = "Skip" ]]; then
						if [ "$videoKind" = "Movie" ]; then
							titleList=`tmdbGetMovieTitles "$getDiscName"`
							if [ ! "$titleList" = "" ]; then
								theTitle=`displayDialogChooseTitle "$titleList"`
								if [[ ! "$theTitle" = "false" && ! "$theTitle" = "" ]]; then
									newDiscName=`echo "$theTitle" | sed 's|\&amp;|\&|g'`
								fi
							else
								appleScriptError
							fi
						elif [ "$videoKind" = "TV Show" ]; then
							titleList=`tvdbGetSeriesTitles "$getDiscName"`							
							if [ ! "$titleList" = "" ]; then
								theSeriesName=`displayDialogChooseTitle "$titleList"`
								if [[ ! "$theSeriesName" = "false" && ! "$theSeriesName" = "" ]]; then
									theSeriesName=`echo "$theSeriesName" | sed -e 's| - First Aired.*$||g' -e 's|\&amp;|\&|g'`
									nameWithSeasonAndDisc=`displayDialogGetSeasonAndDisc "$theSeriesName" "$thePath"`
									if [ ! -z "$nameWithSeasonAndDisc" ]; then
										newDiscName="${theSeriesName} - ${nameWithSeasonAndDisc}"
									fi
								fi
							else
								appleScriptError
							fi
						fi
					fi
				fi
				if [ ! "$newDiscName" = "" ]; then
					echo "${thePath}:${videoKind}:${newDiscName}" >> "$currentItemsList"
				else
					echo "${thePath}:${videoKind}" >> "$currentItemsList"
				fi
			else
				echo "${thePath}:Ignore" >> "$currentItemsList"
			fi
			if [[ $itemCount -eq 1 && $processDisc -eq 1 ]]; then
				#osascript -e "tell application \"Automator Runner\" to display dialog \"$itemCount\""
				runScript "$scriptPath" "$scriptArgs"
			fi
		else
			# Process discs if set to run automatically
			echo "${thePath}:${videoKind}" >> "$currentItemsList"			
			if [[ $itemCount -eq 1 ]]; then
				#osascript -e "tell application \"Automator Runner\" to display dialog \"RUN SCRIPT\""
				runScript "$scriptPath" "$scriptArgs"
			fi
		fi	
	else
		exit 0
	fi
	itemCount=$((itemCount - 1))
done

if [ -d "$tmpFolder" ]; then
	rm -rf $tmpFolder
fi

exit 0