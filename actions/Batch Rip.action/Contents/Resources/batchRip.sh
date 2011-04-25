# !/bin/sh

# batchRip.sh is a script to batch rip dvds with FairMount or MakeMKV
# Copyright (C) 2009-2010  Robert Yamada

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

# Change Log:
# 0.20090606.0 - inital release
# 2.20090719.0 - added test for discs with same name
# 3.20090720.0 - changed output dir to arg
# 4.20090922.0 - added test to quit if no discs are found
# 5.20090924.0 - adding makemkv ripping functions
# 6.20091006.0 - adding args for automator
# 7.20091023.0 - adding back append discs with same name
# 8.20091118.0 - added support for batch rip dispatcher
# 9.20091119.0 - added discCount to minimize wait time
#10.20091120.1 - added back support for skipping duplicates
#11.20091201.0 - Finally got around to adding subroutine to parse variables as args
#12.20091204.0 - added discIdent Query to identify titles
#13.20101113.0 - updated makemkv routine
#############################################################################
# globals

######### CONST GLOBAL VARIABLES #########
scriptName=`basename "$0"`
scriptVers="1.0.5"
scriptPID=$$
E_BADARGS=65

######### USER DEFINED VARIABLES #########
# "$moviePath" "$tvPath" "$videoKind" "$bdRom" "$dvdRom" "$growlMe" "$useOnlyMakeMKV" "$ejectDisc"

# SET OUTPUT PATHS
movieOutputDir="/Volumes" # set the movie search directory 
tvOutputDir="/Volumes"		 # set the tv show search directory 

######### SWITCHES & OVERRIDES (TRUE=1/FALSE=0) #########
encodeHdSources="1"    # if set to 0, will only encode VIDEO_TS (DVDs)
encodeDvdSources="1"
onlyMakeMKV="0"        # if set to 1, will use MakeMKV for DVDs and BDs
growlMe="0"            # if set to 1, will use growlNotify to send encode message
ejectDisc="0"          # Eject disk/s when done (yes/no)
videoKind="TV Show" # Sets Default Video Kind
makeFoldersForMe=0	   # if set to 1, will create input & output folders if they don't exist
saveLog="1"			   # saves session log to ~/Library/Logs/BatchRipActions
skipDuplicates="1"     # if set to 0, if folder with same name exists, will copy disc and append pid # to name

# SET DEFAULT TOOL PATHS
fairmountPath="/Applications/FairMount.app"
makemkvconPath="/Applications/MakeMKV.app/Contents/MacOS/makemkvcon" # path to makemkvcon
mkvinfoPath="/usr/local/bin/mkvinfo" # path to mkvinfo
mkvmergePath="/usr/local/bin/mkvmerge" # path to mkvmerge
growlNotify="/usr/local/bin/growlnotify"     # Path to growlNotify tool

# SET MIN AND MAX TRACK TIME
minTrackTimeTV="20"	    # this is in minutes
maxTrackTimeTV="120"	# this is in minutes
minTrackTimeMovie="80"	# this is in minutes
maxTrackTimeMovie="180"	# this is in minutes

# SET PREFERRED AUDIO LANGUAGE
audioLanguage="English" # set to English, Espanol, Francais, etc.

#############################################################################
# functions

parseVariablesInArgs() # Parses args passed from main.command
{
	if [ -z "$1" ]; then
		return
	fi

	while [ ! -z "$1" ]
	do
		case "$1" in
			( --skipDuplicates ) skipDuplicates=$2
			shift ;;
			( --encodeHdSources ) encodeHdSources=$2
			shift ;;
			( --saveLog ) saveLog=$2
			shift ;;
			( --fairmountPath ) fairmountPath=$2
			shift ;;
			( --makemkvPath ) makemkvPath=$2
			shift ;;
			( --movieOutputDir ) movieOutputDir=$2
			shift ;;
			( --tvOutputDir ) tvOutputDir=$2
			shift ;;
			( --encodeDvdSources ) encodeDvdSources=$2
			shift ;;
			( --growlMe ) growlMe=$2
			shift ;;
			( --onlyMakeMKV ) onlyMakeMKV=$2
			shift ;;
			( --ejectDisc ) ejectDisc=$2
			shift ;;
			( --minTrackTimeTV ) minTrackTimeTV=$2
			shift ;;
			( --maxTrackTimeTV ) maxTrackTimeTV=$2
			shift ;;
			( --minTrackTimeMovie ) minTrackTimeMovie=$2
			shift ;;
			( --maxTrackTimeMovie ) maxTrackTimeMovie=$2
			shift ;;
			( * ) echo "Args not recognized" ;;
		esac
		shift
	done

	# fix spaces in paths
	fairmountPath=`echo "$fairmountPath" | tr ':' ' '`
	makemkvconPath=`echo "$makemkvPath" | tr ':' ' ' | sed 's|$|/Contents/MacOS/makemkvcon|'`
	movieOutputDir=`echo "$movieOutputDir" | tr ':' ' '`
	tvOutputDir=`echo "$tvOutputDir" | tr ':' ' '`
}

makeFoldersForMe() # Creates the output folders when makeFoldersForMe is set to 1
{
	if [[ makeFoldersForMe -eq 1 ]]; then
		if [ ! -d "$movieOutputDir" ]; then
			mkdir "$movieOutputDir"
		fi
		if [ ! -d "$tvOutputDir" ]; then
			mkdir "$tvOutputDir"
		fi
	fi
}

sanityCheck () # Checks that apps are installed and input/output paths exist
{
	
	toolList="$fairmountPath"

	if [[ $encodeHdSources -eq 1 || $onlyMakeMKV -eq 1 ]]; then
		toolList="$toolList|$makemkvconPath"
	fi
	if [[ $growlMe -eq 1 ]]; then
		toolList="$toolList|$growlNotifyPath"
	fi
	
	toolList=`echo $toolList | tr ' ' '\007' | tr '|' '\n'`
	for eachTool in $toolList
	do
		toolPath=`echo $eachTool | tr '\007' ' '`
		toolName=`echo "$toolPath" | sed 's|.*/||'`
		if [ ! -x "$toolPath" ]; then
				echo -e "\n    ERROR: $toolName command tool is not setup to execute"
				toolPath=`verifyFindCLTool "$toolPath"`
				echo "    ERROR: attempting to use tool at $toolPath"
				echo ""
			if [ ! -x "$toolPath" ]; then
				echo "    ERROR: $toolName command tool could not be found"
				echo "    ERROR: $toolName can be installed in ./ /usr/local/bin/ /usr/bin/ ~/ or /Applications/"
				echo ""
				errorLog=1
			fi
		fi
	done
	
	# see if the input/output directories exist
	if [[ ! -e "$movieOutputDir" ]]; then
		echo "    ERROR: $movieOutputDir could not be found"
		echo "    Check \$movieOutputDir to set your Batch Rip Movies folder"
		echo ""
		errorLog=1
	fi
	if [[ ! -e "$tvOutputDir" ]]; then
		echo "    ERROR: $tvOutputDir could not be found"
		echo "    Check \$tvOutputDir to set your Batch Rip TV folder"
		echo ""
		errorLog=1
	fi

	# exit if sanity check failed
	if [[ errorLog -eq 1 ]]; then
		exit $E_BADARGS
	fi
	
	# get onlyMakeMKV setting for setup info
	if [[ onlyMakeMKV -eq 0 ]]; 
		then onlyMakeMKVStatus="No"
		else onlyMakeMKVStatus="Yes"	
	fi

	# get growlMe setting for setup info
	if [[ growlMe -eq 0 ]]; 
		then growlMeStatus="No"
		else growlMeStatus="Yes"	
	fi

	# get encodeHdSources setting for setup info
	if [[ encodeHdSources -eq 0 ]]; 
		then encodeHdStatus="No"
		else encodeHdStatus="Yes"	
	fi

	# get ejectdisk setting for setup info
	if [[ ejectDisc -eq 0 ]]; 
		then ejectDiscStatus="No"
		else ejectDiscStatus="Yes"	
	fi
	
}	

verifyFindCLTool() # Attempt to find tool path when default path fails
{
	toolPath="$1"
	toolName=`echo "$1" | sed 's|.*/||'`
	
	if [ ! -x "$toolPath" ]; then
		if echo "$toolName" | egrep -i "FairMount" > /dev/null ; then
			toolPathTMP="/Applications/${toolName}"
		else
			toolPathTMP=`PATH=.:/Applications:/:/usr/bin:/usr/local/bin:$HOME:$PATH which $toolName | sed '/^[^\/]/d' | sed 's/\S//g'`
		fi		
		if [ ! -z $toolPathTMP ]; then 
			toolPath=$toolPathTMP
		fi
	fi
	echo "$toolPath"
}

processVariables () 
{
	deviceName=`diskutil info "$1" | grep "Device / Media Name:" | sed 's|.* ||'`
	discType=`diskutil info "$1" | grep "Optical Media Type" | sed 's|.*: *||'`
	discName=`diskutil info "$1" | grep "Volume Name:" | sed 's|.*: *||'`
	deviceNum=`echo "$deviceList" | grep "$deviceName" | awk -F: '{print $1-1}'`
	if [ "$discType" = "DVD-ROM" ]; then
			thisDisc=`echo "$1" | tr ' ' '\007' | tr '\000' ' '`
			dvdList="$dvdList $thisDisc"
			dvdList=`echo "$dvdList" | sed 's|^ ||'`
	fi
	if [ "$discType" = "BD-ROM" ]; then
			thisDisc=`echo "$1" | tr ' ' '\007' | tr '\000' ' '`
			bdList="$bdList $thisDisc"
			bdList=`echo "$bdList" | sed 's|^ ||'`
	fi	
}

processDiscs () 
{
	sourcePath="$1"
	deviceName=`diskutil info "$1" | grep "Device / Media Name:" | sed 's|.* ||'`
	discType=`diskutil info "$1" | grep "Optical Media Type" | sed 's|.*: *||'`
	discName=`diskutil info "$1" | grep "Volume Name:" | sed 's|.*: *||'`
	deviceNum=`echo "$deviceList" | grep "$deviceName" | awk -F: '{print $1-1}'`
	userVideoKind=`grep "$1" < $tmpFolder/currentItems.txt | awk -F: '{print $2}'`
	discCount=`echo "$dvdList" | grep -c ""`
	if [ ! -z "$userVideoKind" ]; then
		videoKind="$userVideoKind"
	fi
	if [ "$videoKind" = "Movie" ]; then
		outputDir="$movieOutputDir"
	elif [ "$videoKind" = "TV Show" ]; then
		outputDir="$tvOutputDir"
	fi
	
	if [[ -d "/Volumes/$discName/VIDEO_TS" && ! onlyMakeMKV -eq 1 ]]; then
		
		# get name from discIdent
		getNameFromDiscIdent=$(discIdentQuery "$sourcePath")
		if [ ! -z "$getNameFromDiscIdent" ]; then
			discName="$getNameFromDiscIdent"
		fi
		
		# copy DVDs with FairMount
		echo ""
		echo "*Scanning ${discType}: $discName "
		if [[ -d "$outputDir"/"$discName" && skipDuplicates -eq 0 ]]; then
			echo "  WARNING: $discName already exists in output directory…"
			discName="${discName}-${scriptPID}"
			echo "  Will RENAME this copy: ${discName}"
		fi
		
		if [[ ! -d "$outputDir"/"$discName" || skipDuplicates -eq 0 ]]; then
		# get Fairmount PID
		PID=`ps uxc | grep -i "Fairmount" | awk '{print $2}'`

		# launch Fairmount
		if [ -z "$PID" ]; then
			open "$fairmountPath"
			if [[ discCount -gt 1 ]]; then
				sleep 30
			else
				sleep 10
			fi
		fi
		
		ditto --noacl -v "$sourcePath" "$outputDir"/"$discName"
		chmod -R 755 "$outputDir"/"$discName"
		setFinderComment "$outputDir"/"$discName" "$videoKind"
		echo -e "$discName\nFinished:" `date "+%l:%M %p"` "\n" >> ${tmpFolder}/growlMessageRIP.txt &
		else
			echo -e "$discName\nSkipped because it already exists\n" >> $tmpFolder/growlMessageRIP.txt &
			echo "  Skipped because folder already exists"
			echo "  Note: Rename existing folder if this is a new disc with the same name"
		fi
	fi	

	if [[ "$discType" = "BD-ROM" || onlyMakeMKV -eq 1  ]]; then
		
		if [ ! "$discType" = "BD-ROM" ]; then
			# get name from discIdent
			getNameFromDiscIdent=$(discIdentQuery "$sourcePath")
			if [ ! -z "$getNameFromDiscIdent" ]; then
				discName="$getNameFromDiscIdent"
			fi
		fi
		
		# make an MKV for each title of a BD, or DVD with makeMKV (if onlyMakeMKV is set to 1)
		echo ""
		echo "*Scanning ${discType}: $discName "

		# get the track number of tracks which are within the time desired based on video kind
		if [ "$videoKind" = "TV Show" ]; then
			trackFetchList=`getTrackListMakeMKV $minTrackTimeTV $maxTrackTimeTV`
		elif [ "$videoKind" = "Movie" ]; then
			trackFetchList=`getTrackListMakeMKV $minTrackTimeMovie $maxTrackTimeMovie`
		fi
					
		printTrackFetchList "$trackFetchList"

		# process each track in the track list
		for aTrack in $trackFetchList
		do
			if [ ! -e "${outputDir}/${discName}-${aTrack}.mkv" ]; then
				# create tmp folder for source
				discNameALNUM=`echo "$discName" | sed 's/[^[:alnum:]^-^_]//g'`
				sourceTmpFolder="${tmpFolder}/${discNameALNUM}"
				if [ ! -e "$sourceTmpFolder" ]; then
					mkdir "$sourceTmpFolder"
				fi
				# makes an mkv file from the HD source
				makeMKV &
				wait
				setFinderComment "${outputDir}/${discName}-${aTrack}.mkv" "$videoKind"
				echo -e "${discName}\nFinished:" `date "+%l:%M %p"` "\n" >> $tmpFolder/growlMessageRIP.txt &
			else
				echo ""
				echo "  ${discName}-${aTrack}.mkv Skipped because file already exists"
				echo "  Note: Rename existing file if this is a new disc with the same name"
			fi
		done		
		echo -e "\n- - - - - - - - - - - - - - - - - - - - - - - - - - - - -"		
	fi

}

discIdentQuery () 
{
	getFolderContents=`ls "${1}/VIDEO_TS"`

	for theDiscItem in $getFolderContents
	do
		filePath=`echo "$theDiscItem" | sed "s|^|${1}/VIDEO_TS/|"`
		fileString=`mdls -name kMDItemFSSize -raw "$filePath" | sed "s|^|/VIDEO_TS/${theDiscItem}:|"`
		theString="$theString:$fileString"
	done

	# get hash code
	generateHash=$(md5 -s "$theString" 2> /dev/null | sed -e 's|.*= ||' -e 's|^\(.\{8\}\)\(.\{4\}\)\(.\{4\}\)\(.\{4\}\)|\1-\2-\3-\4-|' | tr 'a-z' 'A-Z')

	# DiscIdent Fingerprint Query
	fingerprintQuery=`curl -s "http://discident.com/v1/$generateHash/"`
	discGnid=`echo "$fingerprintQuery" | sed -e 's|.*gtin": \"||' -e 's|".*||'`

	# DiscIdent GTIN Query
	gnidQuery=`curl -s "http://discident.com/v1/$discGnid/"`

	discName=`echo "$fingerprintQuery" | sed -e 's|.*title": "||' -e 's|".*||'`
	if [ ! -z "$discName" ]; then
		discYear=`echo "$gnidQuery" | sed -e 's|.*productionYear": ||' -e 's|[^0-9*].*||'`
		if [ ! -z "$discYear" ]; then
			discName="$discName ($discYear)"
		fi
	fi

	echo "$discName"
}

getTrackListMakeMKV() # Gets the only the tracks with in the min/max duration
{
	aReturn=""
	duplicateList=""

	#	parse track info for BD optical disc
	#   gets a list of tracks added by makemkv, weeds out angle2 & 3 tracks
	minTime="$1"
	maxTime="$2"
	minTimeSecs=$[$minTime*60]
	trackList=`"$makemkvconPath" -r --minlength=$minTimeSecs info disc:$deviceNum | egrep 'TINFO\:.,9,0'`
	#scanTitles=`"$makemkvconPath" info disc:$deviceNum | egrep '(003036:000000:0000|003316:000000:0000 |003313:000000:0000|003317:000000:0000)' | sed 's|003316:000000:0000.* in file||g' | tr '\n' ',' | sed -e 's|title #[0-9]|&\||g' | tr '|' '\n' | sed -e 's|,|\||g' -e 's|\| |\||g' -e 's|^ ||' -e 's| |+|g' -e 's|^\|||' -e 's|\|$||' | grep -v "angle+2" | grep -v "angle+3"`
	# BDresult=00000.m2ts|003313:000000:0000+File+00012.mpls+was+added+as+title+#0
	# DVDresult=003036:000000:0000+Title+#0+was+added+(41+cell(s)|1:54:42)

	trackNumber=""
	for aline in $trackList
	do
		trackNumber=`echo $aline | sed 's|TINFO:||' | sed 's|,.*||'`
		set -- `echo $aline | grep '[0-9]:[0-9].:[0-9].' | sed -e 's|.*,\"||g' -e 's|"||g' -e 's/:/ /g'`
		if [ $3 -gt 29 ];
			then let trackTime=(10#$1*60)+10#$2+1
		else let trackTime=(10#$1*60)+10#$2
		fi
		if [[ $trackTime -gt $minTime && $trackTime -lt $maxTime ]];
			then titleList="$titleList $trackNumber"
		fi

		if [ "$videoKind" = "Movie" ]; then
			aReturn=`echo "$titleList" | awk -F\  '{print $1}'`
		elif [ "$videoKind" = "TV Show" ]; then
			aReturn="$titleList"
		fi
	done

	# returns the final list of titles to be encoded	
	echo "$aReturn"
}

printTrackFetchList() # Prints the tracks to encode for each source
{
	if [ ! -z "$1" ]; then
		echo "  Will copy the following tracks: `echo $1 | sed 's/ /, /g'` "
	else
		echo "  No tracks on this disc are longer then the minimum track time setting"
	fi
	echo ""
}

isPIDRunning() # Checks on the status of background processes
{
	aResult=0

	if [ $# -gt 0 ]; then
		txtResult="`ps ax | egrep \"^[ \t]*$1\" | sed -e 's/.*/1/'`"
		if [ -z "$txtResult" ];
			then aResult=0
		else aResult=1
		fi
	fi

	echo $aResult
}

makeMKV() # Makes an mkv from a title using a disc as source. Extracts main audio/video, no subs.
{
	tmpFile="${outputDir}/title0${aTrack}.mkv"
	outFile="${outputDir}/${discName}-${aTrack}.mkv"
	audioLang=`echo "$1" | cut -c 1-3 | tr [A-Z] [a-z]`
	makemkvconPath=`verifyFindCLTool "$makemkvconPath"`
	mkvinfoPath=`verifyFindCLTool "$mkvinfoPath"`
	mkvmergePath=`verifyFindCLTool "$mkvmergePath"`

	# uses makeMKV to create mkv file from selected track
	# makemkvcon includes all languages and subs, no way to exclude unwanted items
	echo ""
	echo "*Creating ${discName}-${aTrack}.mkv from Track: ${aTrack}"
	if [ ! -e "$outFile" ]; then
		
		cmd="\"$makemkvconPath\" mkv --messages=-null --progress=${sourceTmpFolder}/${aTrack}-makemkv.txt --decrypt disc:$deviceNum $aTrack \"$outputDir\" > /dev/null 2>&1"
		eval $cmd &
		cmdPID=$!
		while [ `isPIDRunning $cmdPID` -eq 1 ]; do
			if [[ -e "$tmpFile" && -e "${sourceTmpFolder}/${aTrack}-makemkv.txt" ]]; then
				cmdStatusTxt="`tail -n 1 ${sourceTmpFolder}/${aTrack}-makemkv.txt | grep 'Current' | sed 's|.*progress|  Progress|'`"
				echo "$cmdStatusTxt"
				printf "\e[1A"
			else
				echo ""
				printf "\e[1A"
			fi
			sleep 0.5s
		done
		echo ""
		wait $cmdPID
	fi

	if [[ -e "$tmpFile" && ! -e "$outFile" ]]; then
		mv "$tmpFile" "$outFile"
	fi

}

setFinderComment() # Sets the output file's Spotlight Comment to TV Show or Movie
{
	osascript -e "try" -e "set theFile to POSIX file \"$1\" as alias" -e "tell application \"Finder\" to set comment of theFile to \"$2\"" -e "end try" > /dev/null
}

get_log () 
{
	cat << EOF | osascript -l AppleScript
	tell application "Terminal"
		set theText to history of tab 1 of window 1
		return theText
	end tell
EOF
}

ejectDisc() # Ejects the discs
{
	if [[ ejectDisc -eq 1 && -d "$1" ]]; then
		diskutil eject "$1"
	fi
}

#############################################################################
# Main Script

# initialization functions

# get window id of Terminal session and change settings set to Pro
windowID=$(osascript -e 'try' -e 'tell application "Terminal" to set Window_Id to id of first window as string' -e 'end try')
osascript -e 'try' -e "tell application \"Terminal\" to set current settings of window id $windowID to settings set named \"Pro\"" -e 'end try'

# process args passed from main.command
parseVariablesInArgs $*

# get number of drives, if more than one, wait for discs
deviceCount=`ioreg -iSr -w 0 -c IODVDBlockStorageDevice | grep "Device Characteristics" | sed -e 's|.*"Product Name"="||' -e 's|".*||' | grep -c ""`
if [[ deviceCount -gt 1 ]]; then
	echo -e "\n- - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
	echo "Initializing Batch Rip…"
	sleep 20
fi

# create tmp folder for script
tmpFolder="/tmp/batchRip-${scriptPID}"
if [ ! -e "$tmpFolder" ]; then
	mkdir "$tmpFolder"
fi

# copy current items list
if [ -e /tmp/batchRip/currentItems.txt ]; then
	grep -v "Ignore" /tmp/batchRip/currentItems.txt > $tmpFolder/currentItems.txt
#	rm -f /tmp/batchRip/currentItems.txt
fi

# perform sanity check and display errors
sanityCheck

# Get current state of Batch Rip Dispatch LaunchAgent
batchRipDispatcherPath="$HOME/Library/LaunchAgents/com.batchRip.BatchRipDispatcher.plist"
currentState=`launchctl list com.batchRip.BatchRipDispatcher`
if [ -z "$currentState" ]; then
	currentState="disabled"
else
	currentState="enabled"
fi

# Set launchd user override.plist to Disabled key to true
if [ "$currentState" = "enabled" ]; then
	launchctl unload -w "$batchRipDispatcherPath"
fi

# create a list of mounted BDs/DVDs in optical drives (up to 3)
#discSearch=`df -T udf | grep "Volumes" | awk -F\ / {'print $2'} | sed 's|^|\/|g' | tr ' ' '\007' | tr '\000' ' '`
discSearch=`cat $tmpFolder/currentItems.txt | awk -F: '{print $1}' | tr ' ' '\007' | tr '\000' ' '`
#discSearch="$1 | tr ' ' '\007' | tr '\000' ' '"
# get device name of optical drives. Need to sort by device name to get disc:<num> for makeMKV 
deviceList=`ioreg -iSr -w 0 -c IODVDBlockStorageDevice | grep "Device Characteristics" | sed -e 's|.*"Product Name"="||' -e 's|".*||' | grep -n "" `

# display the basic setup information
echo -e "\n- - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
echo -e "$scriptName v$scriptVers\n"
echo "  Start: `date`"
echo "  TV Show Output directory: $tvOutputDir"
echo "  Movie Output directory: $movieOutputDir"
echo "  Use only MakeMKV: $onlyMakeMKVStatus"
echo "  Encode HD Sources: $encodeHdStatus"
echo "  Growl me when complete: $growlMeStatus"
echo "  Eject discs when complete: $ejectDiscStatus"
echo "  Copy TV Shows between: ${minTrackTimeTV}-${maxTrackTimeTV} mins (for MakeMKV)"
echo "  Copy Movies between: ${minTrackTimeMovie}-${maxTrackTimeMovie} mins (for MakeMKV)"
echo ""

if [ ! -z "$discSearch" ]; then

	# display the list of discs found
	echo "  WILL COPY THE FOLLOWING DISCS:"
	for eachdisc in $discSearch
	do
		eachdisc=`echo "$eachdisc" | tr '\007' ' '`
		processVariables "$eachdisc"
		echo "    $discName"
	done
	echo -e "\n- - - - - - - - - - - - - - - - - - - - - - - - - - - - -"

	# begin encode log for growlNotify
	echo "BATCH RIP SUMMARY" > ${tmpFolder}/growlMessageRIP.txt
	echo -e "Started:" `date "+%l:%M %p"` "\n" >> ${tmpFolder}/growlMessageRIP.txt
	
	# process each DVD video found
	if [[ encodeDvdSources -eq 1 ]]; then
		for eachdvd in $dvdList
		do
			eachdvd=`echo "$eachdvd" | tr '\007' ' '`
			if [[ onlyMakeMKV -eq 0 ]]; then
				processDiscs "$eachdvd" &
			else
				processDiscs "$eachdvd" &
				wait
			fi
			if [[ onlyMakeMKV -eq 0 ]]; then
				loop=0
				dittoPID=`ps uxc | grep -i "Ditto" | awk '{print $2}'`
				while [ `isPIDRunning $dittoPID` -eq 0 ]; do
					sleep 1s
					dittoPID=`ps uxc | grep -i "Ditto" | awk '{print $2}'`
					loop=$((loop + 1))
					if [[ loop -gt 30 ]]; then
						break 1
					fi
				done
			fi
		done
		if [[ onlyMakeMKV -eq 0 ]]; then
			fairMountPID=`ps uxc | grep -i "Fairmount" | awk '{print $2}'`
			while [ `isPIDRunning $dittoPID` -eq 1 ]; do
				sleep 1s
				dittoPID=`ps uxc | grep -i "Ditto" | awk '{print $2}'`
			done
			if [[ -z "$dittoPID" && ! -z "$fairMountPID" ]]; then
				# quit Fairmount
				kill $fairMountPID
				echo -e "\n- - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
			fi
		fi
	fi
	
	# process each BD video found
	if [[ encodeHdSources -eq 1 ]]; then	
		for eachbd in $bdList
		do
			eachbd=`echo "$eachbd" | tr '\007' ' '`
			processDiscs "$eachbd" &
		done
		wait
	fi
		
	# display: processing complete
	echo ""
	echo -e "\nPROCESSING COMPLETE"
	echo "-- End summary for $scriptName" >> ${tmpFolder}/growlMessageRIP.txt && sleep 2

	########  GROWL NOTIFICATION  ########
	if [[ $growlMe -eq 1 ]]; then
		open -a GrowlHelperApp && sleep 5
		growlMessage=$(cat ${tmpFolder}/growlMessageRIP.txt)
		growlnotify "Batch Rip" -m "$growlMessage" && sleep 5
	fi
else
	echo "  ERROR: No discs found"
	echo "  Check optical drive, discs and settings"
	exit $E_BADARGS
fi

# Set launchd user override.plist to Disabled key to false
if [ "$currentState" = "enabled" ]; then
	launchctl load -w "$batchRipDispatcherPath"
fi

# delete script temp files
if [ -e "$tmpFolder" ]; then
	rm -rf $tmpFolder
fi

# delete script temp files
if [ -e "$tmpFolder" ]; then
	rm -rf $tmpFolder
fi

# delete bash script tmp file
if [ -e /tmp/batchRipTmp.sh ]; then
	rm -f /tmp/batchRipTmp.sh
fi

# if ejectDisc is set to 1, ejects the discs
for eachdisc in $discSearch
do
	sleep 3
	ejectDisc "$eachdisc"
done

echo "End: `date`"
echo -e "- - - - - - - - - - - - - - - - - - - - - - - - - - - - -\n"

if [[ saveLog -eq 1 ]]; then
	theLog=`get_log`
	test -d "$HOME/Library/Logs/BatchRipActions" || mkdir "$HOME/Library/Logs/BatchRipActions"
	echo "$theLog" > "$HOME/Library/Logs/BatchRipActions/BatchRip.log"
	#osascript -e 'try' -e "tell application \"Terminal\" to close window id $windowID" -e 'end try'
fi

exit 0
