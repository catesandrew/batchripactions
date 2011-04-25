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

#  Copyright (c) 2009 Robert Yamada
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


function appleScriptDialog () {
	cat << EOF | osascript -l AppleScript
		-- BLU-RAY LAUNCH BATCH RIP
		-- CANCEL AFTER 30 SECONDS OF NO INPUT
tell application "Automator Runner"
	activate
	display dialog "$2" & " Detected: " & return Â
		& "$1" & return Â
		& "Select a video kind to continue." buttons {"Ignore", "TV Show", "Movie"} default button 1 giving up after 30 with icon 0
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

function runScript () {
		scriptTmpPath="/tmp/batchRipTmp.sh"
		echo "\"$1\" \"$2\"" > "$scriptTmpPath"
		chmod 777 "$scriptTmpPath"
		open -a Terminal "$scriptTmpPath"
}

while read thePath
do
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
		if [[ ! "${videoKind}" ]]; then videoKind="0"; fi
		if [[ videoKind -eq 0 ]]; then videoKind="Movie"; fi
		if [[ videoKind -eq 1 ]]; then videoKind="TV Show"; fi
		
		# Set path to batchRip.sh
		scriptPath="$HOME/Library/Automator/Batch Rip.action/Contents/Resources/batchRip.sh"

		# Check if this disc is currently being processed
		bashPID=`ps uxc | grep -i "Bash" | awk '{print $2}'`
		for eachPID in $bashPID
		do
			if grep "$thePath" < /tmp/batchRip-$eachPID/currentItems.txt ; then
				exit 0
			fi
		done

		# Temporarily replace spaces in paths
		fairmountPath=`echo "$fairmountPath" | tr ' ' ':'`
		moviePath=`echo "$moviePath" | tr ' ' ':'`
		tvPath=`echo "$tvPath" | tr ' ' ':'`
		
		# Set scriptArgs
		scriptArgs="--skipDuplicates $skipDuplicates --encodeHdSources $bdRom --saveLog $saveLog --fairmountPath $fairmountPath --movieOutputDir $moviePath --tvOutputDir $tvPath --encodeDvdSources $dvdRom --growlMe $growlMe --onlyMakeMKV $useOnlyMakeMKV --ejectDisc $ejectDisc"
		
		# Make temp folder
		if [ ! -d /tmp/batchRip ]; then
			mkdir /tmp/batchRip
		fi
			
		# Process discs if set to not run automatically
		if [[ ! autoRun -eq 1 ]]; then
		
			# Get user input for action
			returnInput=`appleScriptDialog "$thePath" "$discType"`
			
			# If video kind is returned, setup and launch batchRip. If ignore is returned, set to ignore.
			if [[ ! "$returnInput" = "Cancel" && ! -z "$returnInput" ]]; then
				videoKind="$returnInput"
				echo "${thePath}:${videoKind}" >> /tmp/batchRip/currentItems.txt
				discList=$(egrep -v '.*:Ignore' < /tmp/batchRip/currentItems.txt)
				discCount=$(echo "$discList" | grep -c "")

				if [[ discCount -lt 2 ]]; then
					runScript "$scriptPath" "$scriptArgs"
				fi
			else
				echo "${thePath}:Ignore" >> /tmp/batchRip/currentItems.txt
			fi
		else
			# Process discs if set to run automatically
			echo "${thePath}:${videoKind}" >> /tmp/batchRip/currentItems.txt
			discList=$(egrep -v '.*:Ignore' < /tmp/batchRip/currentItems.txt)
			discCount=$(echo "$discList" | grep -c "")
			if [[ discCount -lt 2 ]]; then
				runScript "$scriptPath" "$scriptArgs"
			fi
			exit 0
		fi	
	else
		exit 0
	fi
done

