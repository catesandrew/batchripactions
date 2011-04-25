# !/bin/sh

# changelog
# 1-20091023-0 - fixed line 786+: egrep error
# 2-20091114-0 - changed movieTagsXml to include tmdbID
# 3-20091119-0 - added save session log
# 4-20091120-0 - added verbose logging for HB
# 5-20091120-1 - fixed aReturn for Movie DVDs
# 6-20091126-0 - added ISO88591 subroutine, add'l work on additunestags
# 7-20091127-0 - changed tool args for improved compatibility with HB 0.9.4
# 8-20091130-0 - added save hb scan to get track info
# 9-20091201-0 - finally got around to adding subroutine to parse variables as args

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


#########################################################################################
# globals

######### CONST GLOBAL VARIABLES #########
scriptName=`basename "$0"`
scriptVers="1.0.4"
scriptPID=$$
E_BADARGS=65

######### USER DEFINED VARIABLES #########

# SET INPUT/OUTPUT PATHS
movieSearchDir="$HOME/Movies/Batch Rip Movies" # set the movie search directory 
tvSearchDir="$HOME/Movies/Batch Rip TV"		 # set the tv show search directory 
outputDir="$HOME/Movies/Batch Encode"			 # set the output directory 
cnidFile="$HOME/Library/Automator/Batch Encode.action/Contents/Resources/cnID.txt"

# SET DEFAULT TOOL PATHS
handBrakeCliPath="/Applications/HandBrakeCLI"
makemkvconPath="/Applications/MakeMKV.app/Contents/MacOS/makemkvcon" # path to makemkvcon
mkvinfoPath="/usr/local/bin/mkvinfo"					# path to mkvinfo
mkvmergePath="/usr/local/bin/mkvmerge"					# path to mkvmerge
mp4tagsPath="/usr/local/bin/mp4tags"					# path to mp4tags
mp4chapsPath="/usr/local/bin/mp4chaps"					# path to mp4chaps
mp4artPath="/usr/local/bin/mp4art"						# path to mp4art
xpathPath="/usr/bin/xpath"								# path to xpath
xmllintPath="/usr/bin/xmllint"							# path to xmllint
atomicParsley64Path="/usr/local/bin/AtomicParsley64"    # path to AtomicParsley64
growlNotifyPath="/usr/local/bin/growlnotify"			# path to growlNofify
tsMuxerCLIPath="/Applications/tsMuxeR" 					# path to tsMuxer CLI

# SET PREFERRED AUDIO LANGUAGE
audioLanguage="English" # set to English, Espanol, Francais, etc.

# SET MIN AND MAX TRACK TIME
minTrackTimeTV="20"	    # this is in minutes
maxTrackTimeTV="120"	    # this is in minutes
minTrackTimeMovie="80"	# this is in minutes
maxTrackTimeMovie="180"	# this is in minutes

######### SWITCHES & OVERRIDES (TRUE=1/FALSE=0) #########
# SET ENCODE TYPE TO OUTPUT
encode_DVD="0"      # if set to 1, this type of file will output
encode_SD="1"       # if set to 0, this type of file will not output
encode_720p="0"     # if set to 1, this type of file will output
encode_1080p="0"    # if set to 0, this type of file will not output

# USE CUSTOM TOOL ARGS
useCustom1080pArgs="0"   # if set to 1, HB will use the custom settings for the source 
useCustom720pArgs="0"    # if set to 1, HB will use the custom settings for the source  
useCustomSdArgs="0"      # if set to 1, HB will use the custom settings for the source  
useCustomDvdArgs="0"     # if set to 1, HB will use the custom settings for the source  

custom1080pArgs="noarrgs"   	# set custom args if you set useCustom1080pArgs to 1
custom720pArgs="noarrgs"   		# set custom args if you set useCustom720pArgs to 1
customSdArgs="noarrgs"   		# set custom args if you set useCustomSdArgs to 1
customDvdArgs="noarrgs"   		# set custom args if you set useCustomDvdArgs to 1

# OVERRIDE SCRIPT DEFAULT SETTINGS. (Not recommended for the less advanced)
encodeHdSources="0" 			# if set to 0, will only encode VIDEO_TS (DVDs)
skipDuplicates="1"			# if set to 0, the new output files will overwrite existing files
ignoreOptical="1"				# if set to 0, will attempt to use any mounted optical disc as a source
growlMe="0"                   # if set to 1, will use growlNotify to send encode message
tsMuxerOverride="0"           # if set to 1 will use tsMuxer instead of makeMKV
videoKindOverride="Movie"   # set to TV Show or Movie for missing variable using disc input
toolArgOverride="noarrgs"   		# set custom args if you set overrideProcessToolArgs to 1
makeFoldersForMe="0"			# if set to 1, will create input & output folders if they don't exist
verboseLog="0"			   # shows HandBrake verbose log and saves to ~/Library/Logs/BatchRipActions

######### OPTIONAL #########
# SWITCH ON AUTO-TAGGING
# if set to 1, will automatically generate and tag mp4 files using themoviedb.org api
addiTunesTags="0"

# IF A MOVIE WITH THE SAME FILENAME ALREADY EXISTS IN YOUR LIBRARY, MOVE THE OLD FILE TO ANOTHER FOLDER
# use if you are re-encoding/replacing existing titles, ie: replacing SD files with HD files
retireExistingFile="0" 		# if set to 1, will move old file to a retired movie folder
libraryFolder="$HOME/Movies/Library" 	# path to your movie library folder
retiredFolder="$HOME/Movies/Retired"	# path to your retired movies folder

#########################################################################################
# functions

parseVariablesInArgs() # Parses args passed from main.command
{
   if [ -z "$1" ]; then
      return
   fi
   
   while [ ! -z "$1" ]
   do
      case "$1" in
	
         ( --verboseLog ) verboseLog=$2
            shift ;;
         ( --movieSearchDir ) movieSearchDir=$2
            shift ;;
         ( --tvSearchDir ) tvSearchDir=$2
            shift ;;
         ( --outputDir ) outputDir=$2
            shift ;;
         ( --handBrakeCliPath ) handBrakeCliPath=$2
            shift ;;
         ( --minTrackTimeTV ) minTrackTimeTV=$2
            shift ;;
         ( --maxTrackTimeTV ) maxTrackTimeTV=$2
            shift ;;
         ( --minTrackTimeMovie ) minTrackTimeMovie=$2
            shift ;;
         ( --maxTrackTimeMovie ) maxTrackTimeMovie=$2
            shift ;;
         ( --encode_720p ) encode_720p=$2
            shift ;;
         ( --encode_SD ) encode_SD=$2
            shift ;;
         ( --encode_1080p ) encode_1080p=$2
            shift ;;
         ( --encodeHdSources ) encodeHdSources=$2
            shift ;;
         ( --ignoreOptical ) ignoreOptical=$2
            shift ;;
         ( --growlMe ) growlMe=$2
            shift ;;
         ( --tsMuxerOverride ) tsMuxerOverride=$2
            shift ;;
         ( --videoKindOverride ) videoKindOverride=$2
            shift ;;
         ( --addiTunesTags ) addiTunesTags=$2
            shift ;;
         ( --retireExistingFile ) retireExistingFile=$2
            shift ;;
         ( --libraryFolder ) libraryFolder=$2
            shift ;;
         ( --retiredFolder ) retiredFolder=$2
            shift ;;
         ( --useCustomDvdArgs ) useCustomDvdArgs=$2
            shift ;;
         ( --useCustom720pArgs ) useCustom720pArgs=$2
            shift ;;
         ( --useCustom1080pArgs ) useCustom1080pArgs=$2
            shift ;;
         ( --useCustomSdArgs ) useCustomSdArgs=$2
            shift ;;
         ( --customDvdArgs ) customDvdArgs=$2
            shift ;;
         ( --custom720pArgs ) custom720pArgs=$2
            shift ;;
         ( --custom1080pArgs ) custom1080pArgs=$2
            shift ;;
         ( --customSdArgs ) customSdArgs=$2
            shift ;;
          ( * ) echo "Args not recognized" ;;
      esac
      
      shift
   done
   
   # fix spaces in paths
   movieSearchDir=`echo "$movieSearchDir" | tr ':' ' '`
   tvSearchDir=`echo "$tvSearchDir" | tr ':' ' '`
   outputDir=`echo "$outputDir" | tr ':' ' '`
   handBrakeCliPath=`echo "$handBrakeCliPath" | tr ':' ' '`
   videoKindOverride=`echo "$videoKindOverride" | tr ':' ' '`
   libraryFolder=`echo "$libraryFolder" | tr ':' ' '`
   retiredFolder=`echo "$retiredFolder" | tr ':' ' '`
   customDvdArgs=`echo "$customDvdArgs" | tr ':' ' '`
   custom720pArgs=`echo "$custom720pArgs" | tr ':' ' '`
   custom1080pArgs=`echo "$custom1080pArgs" | tr ':' ' '`
   customSdArgs=`echo "$customSdArgs" | tr ':' ' '`
}

makeFoldersForMe()
{
	if [[ makeFoldersForMe -eq 1 ]]; then
		if [ ! -d "$tvSearchDir" ]; then
			mkdir "$tvSearchDir"
		fi
		if [ ! -d "$movieSearchDir" ]; then
			mkdir "$movieSearchDir"
		fi
		if [ ! -d "$outputDir" ]; then
			mkdir "$outputDir"
		fi
	fi
}

sanityCheck () # Checks that apps are installed and input/output paths exist
{
	
	toolList="$handBrakeCliPath|$mp4tagsPath"

	if [[ "$addiTunesTags" -eq 1 ]]; then
		toolList="$toolList|$xpathPath|$atomicParsley64Path"
	fi
	if [[ $encodeHdSources -eq 1 ]]; then
		toolList="$toolList|$makemkvconPath|$mkvinfoPath|$mkvmergePath"
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
	if [[ ! -e "$movieSearchDir" ]]; then
		echo "    ERROR: $movieSearchDir could not be found"
		echo "    Check \$movieSearchDir to set your Batch Rip Movies folder"
		echo ""
		errorLog=1
	fi
	if [[ ! -e "$tvSearchDir" ]]; then
		echo "    ERROR: $tvSearchDir could not be found"
		echo "    Check \$tvSearchDir to set your Batch Rip TV folder"
		echo ""
		errorLog=1
	fi
	if [ ! -e "$outputDir" ]; then
		echo "    ERROR: $outputDir could not be found"
		echo "    Check \$outputDir to set your output folder"
		echo ""
		errorLog=1
	fi

	# exit if sanity check failed
	if [[ errorLog -eq 1 ]]; then
		exit $E_BADARGS
	fi
}	

verifyFindCLTool() # Attempt to find tool path when default path fails
{
	toolPath="$1"
	toolName=`echo "$1" | sed 's|.*/||'`
	
	if [ ! -x "$toolPath" ];
	then
		toolPathTMP=`PATH=.:/Applications:/:/usr/bin:/usr/local/bin:$HOME:$PATH which $toolName | sed '/^[^\/]/d' | sed 's/\S//g'`
		
		if [ ! -z $toolPathTMP ]; then 
			toolPath=$toolPathTMP
		fi
	fi
	echo "$toolPath"
}

searchForFilesAndFolders() # Searches input directories for videos to encode
{
	# spaces in file path temporarily become /007 and paths are separ with spaces
	discSearch=`df -T udf | grep "Volumes" | awk -F\ / {'print $2'} | sed 's|^|\/|g'` # all discs
	discString=`echo "$discSearch" | sed 's|.*|"&"|' | tr '\n' ' '`

	# get device name of optical drives. Need to sort by device name to get disc:<num> for makeMKV 
	deviceList=`ioreg -iSr -w 0 -c IODVDBlockStorageDevice | grep "Device Characteristics" | sed -e 's|.*"Product Name"="||' -e 's|".*||' | grep -n "" `
	
	if [[ ignoreOptical -eq 0 && ! -z "$discSearch" ]]; then
		if [[ encodeHdSources -eq 1 ]]; then			
			discListCmd="find \"$movieSearchDir\" \"$tvSearchDir\" $discString \( -type d -name BDMV -o -type d -name VIDEO_TS -o -type f -maxdepth 1 -name *.mkv -o -type f -maxdepth 2 -name *.m2ts \) -print0 | tr ' ' '\007' | tr '\000' ' '"
			discList=`eval $discListCmd`
		else
			discListCmd="find \"$movieSearchDir\" \"$tvSearchDir\" $discString -type d -name VIDEO_TS -print0 | tr ' ' '\007' | tr '\000' ' '"
			discList=`eval $discListCmd`
		fi
	else
		if [[ encodeHdSources -eq 1 ]]; then
			discList=`find "$movieSearchDir" "$tvSearchDir" \( -type d -name BDMV -o -type d -name VIDEO_TS -o -type f -maxdepth 1 -name *.mkv -o -type f -maxdepth 2 -name *.m2ts \) -print0 | tr ' ' '\007' | tr '\000' ' '`
		else
			discList=`find "$movieSearchDir" "$tvSearchDir" -type d -name VIDEO_TS -print0 | tr ' ' '\007' | tr '\000' ' '`
		fi
	fi
	
	# sets encode string for setup info
	encodeBd=$(echo "$discList" | grep "BDMV")
	encodeDvd=$(echo "$discList" | grep "VIDEO_TS")
	if [ ! "$encodeBd" = "" ]; then
		encodeString="${encodeString} MKV/1080p"
	fi
	if [ ! "$encodeDvd" = "" ]; then
		if [[ useCustomDvdArgs -eq 1 ]]; 
			then encodeString="${encodeString} CUSTOM/DVD"
			else encodeString="${encodeString} SD/DVD"
		fi
	fi
	if [[ "$encode_1080p" -eq 1 ]]; then
		if [[ useCustom1080pArgs -eq 1 ]]; 
			then encodeString="${encodeString} CUSTOM 1080p"
			else encodeString="${encodeString} 1080p"
		fi
	fi
	if [[ "$encode_720p" -eq 1 ]]; then
		if [[ useCustom720pArgs -eq 1 ]]; 
			then encodeString="${encodeString} CUSTOM 720p"
			else encodeString="${encodeString} 720p"
		fi		
	fi
	if [[ "$encode_SD" -eq 1 ]]; then
		if [[ useCustomSdArgs -eq 1 ]]; 
			then encodeString="${encodeString} CUSTOM SD"
			else encodeString="${encodeString} SD"
		fi
	fi
	encodeString=`echo $encodeString | sed -e 's| |, |g'`
	
	# get ignore optical setting for setup info
	if [[ ignoreOptical -eq 1 ]]; 
		then opticalStatus="No"
		else opticalStatus="Yes"	
	fi

	# get skipDuplicates setting for setup info
	if [[ skipDuplicates -eq 0 ]]; 
		then skipDuplicatesStatus="No"
		else skipDuplicatesStatus="Yes"	
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

	# get retireExistingFile setting for setup info
	if [[ retireExistingFile -eq 0 ]]; 
		then retireExistingFileStatus="No"
		else retireExistingFileStatus="Yes"	
	fi

	# get use tmdb setting for setup info
	if [[ "$addiTunesTags" -eq 0 ]]; 
		then addTagsStatus="No"
		else addTagsStatus="Yes"	
	fi

	# get use tsMuxerOverride setting for setup info
	if [[ "$tsMuxerOverride" -eq 0 ]]; 
		then tsMuxerOverrideStatus="No"
		else tsMuxerOverrideStatus="Yes"	
	fi
}

processVariables() # Sets the script variables used for each source
{
	# correct the tmp char back to spaces in the disc file paths
	pathToSource=`echo $1 | tr '\007' ' '`
	tmpDiscPath=`dirname "$pathToSource"`
	tmpDiscName=`basename "$tmpDiscPath"`
	
	# get discPath, discName
	if echo "$pathToSource" | egrep '(m2ts|mkv)' > /dev/null ; then
		discName=`basename "$pathToSource" | sed 's|\..*$||g'`
		sourcePath="$pathToSource"
		sourceType="File"
	elif echo "$discSearch" | grep "$tmpDiscPath" > /dev/null ; then
		sourceType="Optical"
		sourcePath=`dirname "$pathToSource"`
		discName=`basename "$sourcePath"`
		deviceName=`diskutil info "$sourcePath" | grep "Device / Media Name:" | sed 's|.* ||'`
		deviceNum=`echo "$deviceList" | grep "$deviceName" | awk -F: '{print $1-1}'`
	else
		sourceType="Folder"
		sourcePath=`dirname "$pathToSource"`
		discName=`basename "$sourcePath"` 
	fi

	# get video kind from spotlight finder comment: TV Show or Movie
	videoKind=""
	videoKind=$(mdls -name kMDItemFinderComment "$sourcePath" | awk -F\" '{print $2}')
	if [ -z "$videoKind" ];	then
		tvFolder=`echo "$tvSearchDir" | sed "s|\/$discName.*||"`
		movieFolder=`echo "$movieSearchDir" | sed "s|\/$discName.*||"`
		if echo "$sourcePath" | grep "$movieFolder" > /dev/null ; then
			videoKind="Movie"
		elif echo "$sourcePath" | grep "$tvFolder" > /dev/null ; then
			videoKind="TV Show"	
		else
			videoKind="$videoKindOverride"			
		fi
	fi

	# set source format HD or DVD
	if [[ -e "$sourcePath/BDMV" || "$sourceType" = "File" ]]; then
		sourceFormat="HD"	
	elif [[ -e "/Volumes/${discName}/VIDEO_TS" || -e "${sourcePath}/VIDEO_TS" ]]; then
		sourceFormat="DVD"
	fi

	# make/set output directory for bd disks
	if [[ "$sourceType" = "Optical" && "$sourceFormat" = "HD" ]]; then
		if [ "$videoKind" = "TV Show" ]; then
			if [ ! -e "${tvSearchDir}/${discName}" ]; then
				mkdir "${tvSearchDir}/${discName}"
			fi	
			folderPath="${tvSearchDir}/${discName}"
		elif [ "$videoKind" = "Movie" ]; then
			if [ ! -e "${movieSearchDir}/${discName}" ]; then
				mkdir "${movieSearchDir}/${discName}"
			fi
			folderPath="${movieSearchDir}/${discName}"
		fi
	else
		folderPath="$sourcePath"	
	fi
	
	# create tmp folder for source
	discNameALNUM=`echo "$discName" | sed 's/[^[:alnum:]^-^_]//g'`
	sourceTmpFolder="${tmpFolder}/${discNameALNUM}"
	if [ ! -e "$sourceTmpFolder" ]; then
		mkdir "$sourceTmpFolder"
	fi	
}

trackFetchListSetup() # Sets the track list variables based on source/type
{
	outFile="$1"
	handBrakeCliPath=`verifyFindCLTool "$handBrakeCliPath"`
	# Set scan command and track info
	if [[ "$sourceType" = "File" || "$sourceFormat" = "DVD" ]]; then
		scanCmd="\"$handBrakeCliPath\" -i \"$sourcePath\" -t 0 /dev/null 2>&1"
		trackInfo=`eval $scanCmd`
		# save HB scan info
		if [ ! -e "${outFile}_titleInfo.txt" ]; then
			echo "$trackInfo" | egrep '[ \t]*\+' > "${outFile}_titleInfo.txt"
		fi
	elif [ "$sourceFormat" = "HD" ]; then
		# if exists, uses eac3to info file to get bd track info
		if [ -e "${outFile}_info.txt" ]; then
			# Fix info file layout
			tr -cd '\11\12\40-\176' < "${outFile}_info.txt" > "${outFile}.tmp"
			if [ -e "${outFile}.tmp" ]; then
				mv "${outFile}.tmp" "${outFile}_info.txt"
			fi
			trackInfo=`cat "${outFile}_info.txt"`
		fi
	fi

	# get the track number of tracks which are within the time desired based on video kind
	if [ "$videoKind" = "TV Show" ]; then
		trackFetchList=`getTrackListWithinDuration $minTrackTimeTV $maxTrackTimeTV "$trackInfo"`
	elif [ "$videoKind" = "Movie" ]; then
		trackFetchList=`getTrackListWithinDuration $minTrackTimeMovie $maxTrackTimeMovie "$trackInfo"`
	fi
}

getTrackListWithinDuration() # Gets the only the tracks with in the min/max duration
{
	# Three input arguments are are needed. 
	#   arg1 is the minimum time in minutes selector
	#   arg2 is the maximum time in minutes selector
	#   arg3 is the raw text stream from the track 0 call to HandBrake (DVD) or the eac3to text file (BD)
	#   for BD source, eac3to info is not necessary, but info is more reliable than makemkv.
	#   returns: a list of track numbers of tracks within the selectors

	if [ $# -lt 2 ]; then
		return ""
	fi

	minTime="$1"
	maxTime="$2"
	shift
	allTrackText="$*"
	aReturn=""
	duplicateList=""

	#	parse track info for DVD and File input
	#   returns a list of titles within the min/max duration
	if [[ "$sourceFormat" = "DVD" || "$sourceType" = "File" ]] ; then
		trackList=`eval "echo \"$allTrackText\" | egrep '(^\+ title |\+ duration\:)' | sed -e 's/^[^+]*+ //'g -e 's/title \([0-9]*\):/\1-/'g -e 's/duration: //'g"`
		trackNumber=""
		for aline in $trackList
		do
			trackLineFlag=`echo $aline | sed 's/[0-9]*-$/-/'`
			if [ $trackLineFlag = "-" ];
				then
				trackNumber=`echo $aline | sed 's/\([0-9]*\)-/\1/'`
			else
				set -- `echo $aline | sed -e 's/(^[:0-9])//g' -e 's/:/ /g'`
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
			fi
		done

	elif [[ "$sourceFormat" = "HD" && tsMuxerOverride -eq 0 || "$sourceFormat" = "HD" && "$sourceType" = "Optical" ]]; then

		#	uses eac3to track info for BD folder input to find tracks outside the min/max duration
		#   creates a track list that contain the tracks that makemkv should skip
		if [ ! "$allTrackText" = "" ]; then
			trackList=`eval "echo \"$allTrackText\" | egrep -v 'angle 2' | egrep '[0-9].*\.mpls.*[0-9]+' | sed -e 's/.*)\ //g' -e 's/\.mpls.*,//g'"`
			trackNumber=""
			for aline in $trackList
			do
				trackLineFlag=`echo $aline | sed 's/[0-9][0-9][0-9][0-9][0-9]$/-/' | sed 's/[0-9]*\.m.*/-/'`
				if [ $trackLineFlag = "-" ];
					then
					trackNumber=`echo $aline | sed 's/\([0-9].*\)-/\1/'`
				else
					set -- `echo $aline | grep '[0-9]:[0-9].:[0-9].' | sed -e 's|\ *||g' -e 's/(^[:0-9])//g' -e 's/:/ /g'`
					if [ $3 -gt 29 ];
						then let trackTime=(10#$1*60)+10#$2+1
					else let trackTime=(10#$1*60)+10#$2
					fi
					if [[ $trackTime -gt $maxTime && $trackTime -lt $minTime ]];
						then trackSkipList="$trackSkipList $trackNumber"
					fi
				fi
			done
		fi

		#	parse track info for BD optical disc and folder input
		#   gets a list of tracks added by makemkv, weeds out angle2 trakcs
		makemkvconPath=`verifyFindCLTool "$makemkvconPath"`
		if [ "$sourceType" = "Folder" ]; then
			scanTitles=`"$makemkvconPath" info file:"$sourcePath" | egrep '(003316:000000:0000 |003313:000000:0000|003317:000000:0000)' | sed 's|003316:000000:0000.* in file||g' | tr '\n' ',' | sed -e 's|title #[0-9]|&\||g' | tr '|' '\n' | sed -e 's|,|\||g' -e 's|\| |\||g' -e 's|^ ||' -e 's| |+|g' -e 's|^\|||' -e 's|\|$||' | grep -v "angle+2" | grep -v "angle+3"`
		elif [ "$sourceType" = "Optical" ]; then
			scanTitles=`"$makemkvconPath" info disc:$deviceNum | egrep '(003316:000000:0000 |003313:000000:0000|003317:000000:0000)' | sed 's|003316:000000:0000.* in file||g' | tr '\n' ',' | sed -e 's|title #[0-9]|&\||g' | tr '|' '\n' | sed -e 's|,|\||g' -e 's|\| |\||g' -e 's|^ ||' -e 's| |+|g' -e 's|^\|||' -e 's|\|$||' | grep -v "angle+2" | grep -v "angle+3"`
		fi

		# if the trackSkipList contains tracks to skip, they are removed from makemkv's title list 
		if [ ! "$trackSkipList" = "" ]; then
			scanTitles=`echo $scanTitles | grep -v $trackSkipList`
		fi

		# compares each title in the title list for duplicates
		# creates a list of titles that match. 0=1, 2=3
		for eachTitle in $scanTitles ;
		do
			thisTrack=`echo "$eachTitle" | sed 's/.*#//'`
			otherTitles=$(echo "$scanTitles" | sed -e "s/$eachTitle//g")
			thisTitle=`echo "$eachTitle" | tr '|' '\n'`
			for eachFile in $thisTitle ;
			do
				checkForDuplicate=$(echo "$otherTitles" | grep "$eachFile")
				if [ ! $checkForDuplicate = "" ] ; then
					duplicateTrack=`echo "$checkForDuplicate" | sed 's/.*#//'`
					duplicatesFound=1
					checkDuplicateList=$(echo "$duplicateList" | grep "$thisTrack")
					if [ "$checkDuplicateList" = "" ] ; then
						duplicateList="${duplicateList}${thisTrack}=${duplicateTrack}, "
					fi
				fi
			done
		done

		# if duplicates are found selects the first item in the duplicate set
		if [ ! -z "$duplicatesFound" ]; then
			titleList=`echo "$duplicateList" | sed 's|=[0-9].||g' | tr ' ' '\n'`
		else
			titleList=`echo "$scanTitles" | sed 's|.*#||'`
		fi

		# if a movie, returns 1 title. if tv show, returns all remaining titles
		if [ "$videoKind" = "Movie" ]; then
			aReturn=`echo "$titleList" | egrep -m1 ".*"`
		elif [ "$videoKind" = "TV Show" ]; then
			aReturn="$titleList"
		fi

	elif [[ "$sourceFormat" = "HD" && tsMuxerOverride -eq 1 ]] ; then 
		#	parse track info for BD with tsMuxer
		trackList=`eval "echo \"$allTrackText\" | egrep -v 'angle 2' | egrep '[0-9].*\.mpls.*[0-9]+' | sed -e 's/.*)\ //g' -e 's/\.mpls.*,//g'"`
		trackNumber=""
		for aline in $trackList
		do
			trackLineFlag=`echo $aline | sed 's/[0-9][0-9][0-9][0-9][0-9]$/-/' | sed 's/[0-9]*\.m.*/-/'`
			if [ $trackLineFlag = "-" ];
				then
				trackNumber=`echo $aline | sed 's/\([0-9].*\)-/\1/'`
			else
				set -- `echo $aline | grep '[0-9]:[0-9].:[0-9].' | sed -e 's|\ *||g' -e 's/(^[:0-9])//g' -e 's/:/ /g'`
				if [ $3 -gt 29 ];
					then let trackTime=(10#$1*60)+10#$2+1
				else let trackTime=(10#$1*60)+10#$2
				fi
				if [[ $trackTime -gt $minTime && $trackTime -lt $maxTime ]];
					then aReturn="$aReturn $trackNumber"
				fi
			fi
		done	
	fi
	# returns the final list of titles to be encoded	
	echo "$aReturn"
}

printTrackFetchList() # Prints the tracks to encode for each source
{
	if [ ! -z "$1" ]; then
		echo "  Will encode the following tracks: `echo $1 | sed 's/ /, /g'` "
	else
		echo "  No tracks on this DVD are longer then the minimum track time setting"
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

makeMKV() # Makes an mkv from an HD source file. Extracts main audio/video, no subs.
{
	tmpFile="${folderPath}/title0${aTrack}.mkv"
	outFile="${folderPath}/${discName}-${aTrack}.mkv"
	audioLang=`echo "$1" | cut -c 1-3 | tr [A-Z] [a-z]`
	makemkvconPath=`verifyFindCLTool "$makemkvconPath"`
	mkvinfoPath=`verifyFindCLTool "$mkvinfoPath"`
	mkvmergePath=`verifyFindCLTool "$mkvmergePath"`

	# uses makeMKV to create mkv file from selected track
	# makemkvcon includes all languages and subs, no way to exclude unwanted items 
	echo "*Creating MKV temp file of Track: ${aTrack}"
		if [[ ! -e "$tmpFile" && ! -e "$outFile" ]]; then
			echo -en "${discName}-${aTrack}.mkv\nEncoded:" `date "+%l:%M %p"` "\c" >> $tmpFolder/growlMessageHD.txt &
			if [ "$sourceType" = "Folder" ]; then
				cmd="\"$makemkvconPath\" mkv file:\"$folderPath\" $aTrack \"$folderPath\" > /dev/null 2>&1"
			elif [ "$sourceType" = "Optical" ]; then
				cmd="\"$makemkvconPath\" mkv disc:$deviceNum $aTrack \"$folderPath\" > /dev/null 2>&1"
			fi
			eval $cmd &
			cmdPID=$!
			du -d 0 -h "$folderPath" | sed -e 's| ||g' -e 's|/.*$||' -e 's|^|    Source size: |'
			echo ""
			while [ `isPIDRunning $cmdPID` -eq 1 ]; do
				printf "\e[1A"
				printf "\e[2K"
				if [ -e "$tmpFile" ]; then
					du -h "$tmpFile" | sed -e 's|^ *||g' -e 's|\/.*$||' -e 's|^|    Output size: |'
				else 
					echo ""
				fi
				sleep 1s
			done
			echo ""
			wait $cmdPID
		fi

		# uses mkvInfo to select correct audio track/language
		if [[ -e "$tmpFile" && ! -e "$outFile" ]]; then
			mkvInfoCmd="\"$mkvinfoPath\" \"$tmpFile\""
			mkvInfo=`eval $mkvInfoCmd`
			audioInfo=`echo "$mkvInfo" | sed 's|\| *||' | tr '\n' '|' | sed 's|\|+ A track|%|g' | tr '%' '\n' | sed -e 's|^\|+ ||' -e 's|\|+|,|g' | egrep ".*Track type: audio" | egrep ".*Language: $audioLang"`
			if [ "$audioInfo" = "" ]; then
				audioLang="eng"
				audioInfo=`echo "$mkvInfo" | sed 's|\| *||' | tr '\n' '|' | sed 's|\|+ A track|%|g' | tr '%' '\n' | sed -e 's|^\|+ ||' -e 's|\|+|,|g' | egrep ".*Track type: audio" | egrep ".*Language: $audioLang"`
			fi
			dtsAc3Test=`echo "$audioInfo" | egrep '(A_DTS|A_AC3)' | egrep '.*Name: 3/2\+1'`

			if [ ! "$dtsAc3Test" = "" ]; then
				getCodec=$(echo "$dtsAc3Test" | sed -e 's|^.*Codec ID: ||' -e 's|,.*||')
				getCodec1Line=$(echo "$getCodec" | tr '\n' ' ' | grep "A_DTS" | grep "A_AC3")

				if [ ! "$getCodec1Line" = "" ]; then
					audioCodec=$(echo "$getCodec" | egrep -m2 '(A_DTS|A_AC3)' | tr '\n' '/' | sed 's|/$||')
					audioTrack=$(echo "$dtsAc3Test" | egrep -m2 '(A_DTS|A_AC3)' | sed -e 's|^Track number: ||' -e 's|,.*||' | tr '\n' ',' | sed 's|,$||')

				elif [ `echo "$getCodec" | grep "A_DTS"` ];
					then
					audioCodec=$(echo "$getCodec" | egrep -m1 "A_DTS")
					audioTrack=$(echo "$dtsAc3Test" | egrep -m1 "A_DTS" | sed -e 's|^Track number: ||' -e 's|,.*||')
				else
					audioCodec=$(echo "$getCodec" | egrep -m1 "A_AC3")
					audioTrack=$(echo "$dtsAc3Test" | egrep -m1 "A_AC3" | sed -e 's|^Track number: ||' -e 's|,.*||')
				fi
			else
				audioCodec=$(echo "$audioInfo" | egrep -m1 'Track type' | sed -e 's|^.*Codec ID: ||' -e 's|,.*||')
				audioTrack=$(echo "$audioInfo" | egrep -m1 'Track type' | sed -e 's|^Track number: ||' -e 's|,.*||')
			fi

			# uses mkvmerge to extract main video & preferred audio language track 
			# excludes other languages & subtitles, creating a new mkv file
			echo -e "*Extracting Main Video and Audio Track ${audioTrack}: ${audioCodec}-${audioLang} from temp file"
			cmd="\"$mkvmergePath\" -o \"$outFile\" -a 1,$audioTrack -S \"$tmpFile\" > ${sourceTmpFolder}/${aTrack}-mkvmerge.txt"
			eval $cmd &
			cmdPID=$!
			while [ `isPIDRunning $cmdPID` -eq 1 ]; do
				cmdStatusTxt="`tail -n 1 ${sourceTmpFolder}/${aTrack}-mkvmerge.txt | grep 'progress: '`"
				if [ ! -z "$cmdStatusTxt" ]; then
					echo -n "$cmdStatusTxt"
				fi
				sleep 1s
			done
			echo ""
			wait $cmdPID
			echo -e "-" `date "+%l:%M %p"` "\n" >> $tmpFolder/growlMessageHD.txt &
		else
			echo -e "${discName}-${aTrack}.mkv\nSkipped because it already exists\n" >> $tmpFolder/growlMessageHD.txt &
			echo "  Skipped because file already exists"
		fi

		# deletes temp mkv file
		if [[ -e "$tmpFile" && -e "$outFile" ]]; then
			rm "$tmpFile"
		fi
}

makeMetaFile() # Creates a tsMuxer metafile, when tsMuxerOverride is set to 1
{
	mplsFile=$1
	outFile="${folderPath}/${discName}"
	if [[ ! -e "$outFile"-$1.meta || skipDuplicates -eq 0 ]] ; then
		# Save tsMuxeR output to file
		"$tsMuxerCLIPath" "$folderPath/BDMV/PLAYLIST/${mplsFile}.mpls" > "${outFile}-${mplsFile}_tsMuxer.txt"

		# Get m2ts info
		m2tsFiles=$(egrep "File #[0-9]+" "${outFile}-${mplsFile}_tsMuxer.txt" | awk -F= '{print $2}' | sed 's|.*|\"&\"|g' | tr '\n' '+' | sed 's|+$||')

		# Get Stream info
		videoInfo=$(cat "${outFile}-${mplsFile}_tsMuxer.txt" | tr '\n' '|' | sed 's|\ \ *|\ |g' | awk -F "4113" '{print $2}' | awk -FTrack '{print $1}' | tr '|' '\n')
		audioInfo=$(cat "${outFile}-${mplsFile}_tsMuxer.txt" | tr '\n' '|' | sed 's|\ \ *|\ |g' | sed 's|^.*\|Track ID:\ 4352|Track ID: 4352|' | awk -FTrack\ ID:\ 46 '{print $1}' | awk 'BEGIN { FS="Track ID: "; OFS="\n" } { print $1, $2, $3, $4, $5, $6, $7 }' | grep "eng" | egrep 'A_AC3|A_DTS' )
		videoFormat=$(echo "$videoInfo" | egrep -m1 "Stream ID:" | awk -F "Stream ID: " '{print $2}')
		frameRate=$(echo "$videoInfo" | egrep -m1 "Frame rate:" | awk -F "Frame rate: " '{print $2}')
		#audioFormat=$(echo "$audioInfo" | egrep -m1 "Stream ID:" | awk -F "Stream ID: " '{print $2}' | tr '|' '\n')
		audioFormat=$(echo "$audioInfo" | tr '|' '\n' | egrep -m1 "Stream ID:" | awk -F "Stream ID: " '{print $2}')
		audioTrack=$(echo "$audioInfo" | egrep -m1 "Stream ID:" | awk -F "Stream ID: " '{print $1}' | sed 's|\|.*$||')
		streamDelay=$(echo "$audioInfo" | egrep -m1 "Stream delay:" | awk -F "Stream delay: " '{print $2}')
		if [ ! -z "$streamDelay" ]; then	
			timeShift=" timeshift=${streamDelay}ms,"
		fi

		# Get Video Format
		case $videoFormat in 
			( V_MS/VFW/WVC1 ) 	videoFormat="V_MS/VFW/WVC1, "$m2tsFiles", fps=$frameRate, track=4113, mplsFile=$mplsFile";; 
			( V_MPEG4/ISO/AVC ) videoFormat="V_MPEG4/ISO/AVC, "$m2tsFiles", fps=$frameRate, insertSEI, contSPS, track=4113, mplsFile=$mplsFile";; 
			( * ) 		 	    videoFormat="V_MPEG-2, "$m2tsFiles", track=4113, mplsFile=$mplsFile";;
		esac

		# Get Audio Format
		case $audioFormat in
			( A_DTS )	audioFormat="A_DTS, "$m2tsFiles", down-to-dts, track=$audioTrack,"$timeShift" lang=eng, mplsFile=$mplsFile";;
			( A_AC3 )  audioFormat="A_AC3, "$m2tsFiles", down-to-ac3, track=$audioTrack,"$timeShift" lang=eng, mplsFile=$mplsFile";;
			( * )		audioFormat="A_AC3, "$m2tsFiles", down-to-ac3, track=$audioTrack,"$timeShift" lang=eng, mplsFile=$mplsFile";;
		esac
				
		# Save Chapter Info
		chapterMarkers=$(egrep "Marks:" "${outFile}-${mplsFile}_tsMuxer.txt" | awk -F "Marks: "  '{print $2}' | tr -d '\n' | tr ' ' '\n')
		echo "$chapterMarkers" | awk '{ print NR" "$0 }' | sed -e 's|^[0-9]|0&|' -e "s|^[0-9]*\([[:digit:]]\{2\}\)|\1|g" -e 's|^[0-9].*|&\|&|' -e 's|[0-9]*:[0-9]*:[0-9]*\.[0-9]*$||g' -e 's|^[0-9]*|CHAPTER&=|' -e 's|\||&CHAPTER|' -e 's|$|NAME=|' -e 's|\ ||g' | tr '|' '\n' | sed 'N;$!P;$!D;$d' > "${folderPath}/${aTrack}.chapters.txt"

		# Write Metadata to File
		echo -e "Creating $discName-$mplsFile.meta\n"
		echo -e "MUXOPT --no-pcr-on-video-pid --new-audio-pes --vbr  --vbv-len=500\n$videoFormat\n$audioFormat" | tee "$outFile"-$mplsFile.meta
		echo ""
	else 
		echo "$discName-$mplsFile.meta SKIPPED because it ALREADY EXISTS"
	fi
}

makeM2tsFile() # Creates a m2tsFile with tsMuxer, when tsMuxerOverride is set to 1
{
	outFile="${folderPath}/${discName}"
	# Check if m2ts file already exists
	if [[ ! -e  "$outFile"-$1.m2ts || skipDuplicates -eq 0 ]] ; then
		echo -e "\nCreating $discName-$1.m2ts"
		# Create m2ts File
		cmd="\"$tsMuxerCLIPath\" \"$outFile\"-$1.meta \"$outFile\"-$1.m2ts 2>/dev/null"
		eval $cmd &
		cmdPID=$!
		wait $cmdPID
		echo ""
		echo "Completed $discName-$1.m2ts"
	else
		echo "$discName-$1.m2ts SKIPPED because it ALREADY EXISTS"
	fi
}

processFiles() # Passes the source file and encode settings for each output file 
{
	sourceFile="$1"
	if [ "$sourceFormat" = "HD" ]; then
		if [[ "$sourceType" = "Folder" || "$sourceType" = "Optical" ]]; then
			if [[ tsMuxerOverride -eq 0 ]]; then
				sourceFile="${folderPath}/${discName}-${aTrack}.mkv"
			else
				sourceFile="${folderPath}/${discName}-${aTrack}.m2ts"
			fi
		fi
		
		if [ -e "$sourceFile" ]; then
			if [[ encode_1080p -eq 1 && "$videoKind" = "TV Show" ]] ; then
				processToolArgs "1080p" "$sourceFile"
				encodeFile "$sourceFile" "${discName}-${aTrack}.mkv" "MKV"
			elif [[ encode_1080p -eq 1 && "$videoKind" = "Movie" ]] ; then
				processToolArgs "1080p" "$sourceFile"
				encodeFile "$sourceFile" "${discName}.mkv" "MKV"
			fi

			if [[ encode_720p -eq 1 && "$videoKind" = "TV Show" ]] ; then
				processToolArgs "720p" "$sourceFile"
				encodeFile "$sourceFile" "${discName}-${aTrack}.m4v" "HD"
			elif [[ encode_720p -eq 1 && "$videoKind" = "Movie" ]] ; then
				processToolArgs "720p" "$sourceFile"
				encodeFile "$sourceFile" "${discName}.m4v" "HD"
			fi

			if [[ encode_SD -eq 1 && "$videoKind" = "TV Show" ]] ; then
				processToolArgs "SD" "$sourceFile"
				encodeFile "$sourceFile" "${discName}-${aTrack} 1.m4v" "SD"
			elif [[ encode_SD -eq 1 && "$videoKind" = "Movie" ]] ; then
				processToolArgs "SD" "$sourceFile"
				encodeFile "$sourceFile" "${discName} 1.m4v" "SD"
			fi
		fi

	elif [ "$sourceFormat" = "DVD" ]; then
		if [ "$videoKind" = "TV Show" ] ; then
			processToolArgs "DVD" "$sourceFile"
			encodeFile "$sourceFile" "${discName}-${aTrack}.m4v" "DVD"
		elif [ "$videoKind" = "Movie" ] ; then
			processToolArgs "DVD" "$sourceFile"
			encodeFile "$sourceFile" "${discName}.m4v" "DVD"
		fi
	fi	
}

processToolArgs() # Sets HandBrake encode settings based on input/output type
{
	encodeType="$1"
	inputFile="$2"
	handBrakeCliPath=`verifyFindCLTool "$handBrakeCliPath"`
	scanFileCmd="\"$handBrakeCliPath\" -i \"$inputFile\" -t0 /dev/null 2>&1"
	scanFile=`eval $scanFileCmd`
	audioInfo=`echo "$scanFile" | grep "\+ [0-9], $audioLanguage" | egrep -m1 "" | sed 's|^.*\+ ||'`
	if [ "$audioInfo" = "" ]; then
		audioLanguage="English"
		audioInfo=`echo "$scanFile" | grep "\+ [0-9], $audioLanguage" | egrep -m1 "" | sed 's|^.*\+ ||'`
		if [ "$audioInfo" = "" ]; then
			audioLanguage="Unknown"
			audioInfo=`echo "$scanFile" | grep "\+ [0-9], $audioLanguage" | egrep -m1 "" | sed 's|^.*\+ ||'`
		fi
	fi
	audioCodec=$(echo $audioInfo | sed -e "s|^.*$audioLanguage (||" -e 's|) .*$||')
	audioTrack=$(echo $audioInfo | sed 's|,.*||')
	
	if [[ "$encodeType" = "DVD" && useCustomDvdArgs -eq 1 ]]; then 
		encodeFormat="Custom/${encodeType}"
	elif [[ "$encodeType" = "1080p" && useCustom1080pArgs -eq 1 ]]; then 
		encodeFormat="Custom/${encodeType}"
	elif [[ "$encodeType" = "720p" && useCustom720pArgs -eq 1 ]]; then 
		encodeFormat="Custom/${encodeType}"
	elif [[ "$encodeType" = "SD" && useCustomSdArgs -eq 1 ]]; then 
		encodeFormat="Custom/${encodeType}"
	else 
		encodeFormat="${audioCodec}/${encodeType}"
	fi
	
	case $encodeFormat in
		( DTS/1080p )		toolArgs="-e x264 -q 20.0 -a ${audioTrack} -E dts -f mkv --width 1920 --maxHeight 1080 --decomb --detelecine -m -x cabac=0:ref=2:me=umh:b-adapt=2:weightb=0:trellis=0:weightp=0";;
		( AC3/1080p )		toolArgs="-e x264 -q 20.0 -a ${audioTrack} -E ac3 -f mkv --width 1920 --maxHeight 1080 --decomb --detelecine -m -x cabac=0:ref=2:me=umh:b-adapt=2:weightb=0:trellis=0:weightp=0";;
		( DTS/720p )		toolArgs="-e x264 -q 21.0 -a ${audioTrack} -E ca_aac -B 320 -6 dpl2 -D 0.0 -f mp4 -4 --width 1280 --maxHeight 720 --decomb --detelecine -m -x cabac=0:ref=2:me=umh:b-adapt=2:weightb=0:trellis=0:weightp=0";;
		( AC3/720p )		toolArgs="-e x264 -q 21.0 -a ${audioTrack},${audioTrack} -E ca_aac,ac3 -B 320,320 -6 dpl2,auto -R 48,auto -D 0.0,0.0 -f mp4 -4 --width 1280 --maxHeight 720 --decomb --detelecine -m -x cabac=0:ref=2:me=umh:b-adapt=2:weightb=0:trellis=0:weightp=0";;
		( DTS/SD )			toolArgs="-e x264 -q 21.0 -a ${audioTrack} -E ca_aac -B 160 -6 dpl2 -R 48 -D 0.0 -f mp4 -f mp4 -X 480 --decomb --detelecine -m -x cabac=0:ref=2:me=umh:b-adapt=2:weightb=0:trellis=0:weightp=0";;
		( AC3/SD )			toolArgs="-e x264 -q 21.0 -a ${audioTrack} -E ca_aac -B 160 -6 dpl2 -R 48 -D 0.0 -f mp4 -f mp4 -X 480 --decomb --detelecine -m -x cabac=0:ref=2:me=umh:b-adapt=2:weightb=0:trellis=0:weightp=0";;
		( DTS/DVD )			toolArgs="-e x264 -q 20.0 -a ${audioTrack} -E ca_aac -B 320 -6 dpl2 -R 48 -D 0.0 -f mp4 -X 720 --loose-anamorphic --decomb --detelecine -m -x cabac=0:ref=2:me=umh:bframes=0:8x8dct=0:trellis=0:subme=6";;
		( AC3/DVD )			toolArgs="-e x264  -q 20.0 -a ${audioTrack},${audioTrack} -E ca_aac,ac3 -B 160,160 -6 dpl2,auto -R 48,Auto -D 0.0,0.0 -f mp4 -X 720 --loose-anamorphic --decomb --detelecine -m -x cabac=0:ref=2:me=umh:bframes=0:8x8dct=0:trellis=0:subme=6";;
		( Custom/1080p )	toolArgs="$custom1080pArgs";;
		( Custom/720p )		toolArgs="$custom720pArgs";;
		( Custom/SD )		toolArgs="$customSdArgs";;
		( Custom/DVD )		toolArgs="$customDvdArgs";;
		( * )				toolArgs="-e x264  -q 20.0 -a ${audioTrack},${audioTrack} -E ca_aac,ac3 -B 160,160 -6 dpl2,auto -R 48,Auto -D 0.0,0.0 -f mp4 -X 720 --loose-anamorphic --decomb --detelecine -m -x cabac=0:ref=2:me=umh:bframes=0:8x8dct=0:trellis=0:subme=6";;
	esac
	
	#echo -e "Using ${encodeFormat}-toolArgs: ${toolArgs}\n"	
}

encodeFile() # Encodes source with HandBrake and sends output files for further processing
{
	inputPath="$1"
	movieFile="$2"
	handBrakeCliPath=`verifyFindCLTool "$handBrakeCliPath"`
	
	if [[ ! -e  "$outputDir/$movieFile" || skipDuplicates -eq 0 ]] ; then
		echo -e "\n*Creating $movieFile" 
		echo -e "Using ${encodeFormat}-toolArgs: ${toolArgs}\n"
		echo -en "$movieFile\nEncoded:" `date "+%l:%M %p"` "\c" >> $tmpFolder/growlMessageHD.txt &

		# encode with verbose level 0
		if [[ verboseLog -eq 0 ]]; then
			# encode cmd for BD
			if [ "$sourceFormat" = "HD" ]; then
				cmd="\"$handBrakeCliPath\" -i \"$inputPath\" -o \"${outputDir}/${movieFile}\" -v0 $toolArgs 2>/dev/null"
			# encode cmd for DVD
			elif [ "$sourceFormat" = "DVD" ]; then
				cmd="\"$handBrakeCliPath\" -i \"$inputPath\" -t $aTrack -o \"${outputDir}/${movieFile}\" -v0 $toolArgs 2>/dev/null"			
			fi
		# encode with verbose level 1	
		elif [[ verboseLog -eq 1 ]]; then
			# encode cmd for BD
			if [ "$sourceFormat" = "HD" ]; then
				cmd="\"$handBrakeCliPath\" -i \"$inputPath\" -o \"${outputDir}/${movieFile}\" -v $toolArgs"
			# encode cmd for DVD
			elif [ "$sourceFormat" = "DVD" ]; then
				cmd="\"$handBrakeCliPath\" -i \"$inputPath\" -t $aTrack -o \"${outputDir}/${movieFile}\" -v $toolArgs"			
			fi
		fi
		
		eval $cmd &
		cmdPID=$!
		wait $cmdPID
		echo ""
		echo -e "-" `date "+%l:%M %p"` "\n" >> $tmpFolder/growlMessageHD.txt &

		# optionally tag files, move existing file in archive and set Finder comments
		if [ -e  "$outputDir/$movieFile" ] ; then
			if [ "$sourceFormat" = "HD" ]; then
				# if file is a movie and movie already exists in archive, move existing file to retired folder
				if [[ ! "$videoKind" = "TV Show" && retireExistingFile -eq 1 ]]; then
					retireExistingFile
				fi
			fi
			
			# adds iTunes style tags to mp4 files
			if [ ! "$3" = "MKV" ] ; then
				if echo "$inputPath" | grep "m2ts" ; then
					addChapsForM2ts "$aTrack"
				fi
				addMetaTags "$3"
				if [[ ! "$videoKind" = "TV Show" && "$addiTunesTags" -eq 1 ]]; then
					addiTunesTagsMovie
				fi
			fi
			
			# set spotlight finder comment of m4v file to "videoKind" for hazel or another script
			setFinderComment "$outputDir/$movieFile" "$videoKind"
		else
			echo "  Script could not complete because $movieFile does NOT exist"
		fi
		
	else
		echo -e "$movieFile\nSkipped because it already exists\n" >> $tmpFolder/growlMessageHD.txt &
		echo -e "\n  $movieFile SKIPPED because it ALREADY EXISTS"
	fi
	echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
}

retireExistingFile() # If the file already exists in movie library, move existing file to retired folder
{
	echo -e "\n*Checking if $movieFile exists in Movie Folder"
	if [ -e "$libraryFolder/$movieFile" ];
		then
		mv "$libraryFolder/$movieFile" "$retiredFolder/$movieFile"
		echo "  $movieFile MOVED to Retired Folder"
	else
		echo "  $movieFile does NOT exist"
	fi	
}

addChapsForM2ts() # Adds chapters to m4v files from a text file, for m2ts sources
{
	echo -e "\nAdding Chapters to $movieFile"
	if [ -e "${folderPath}/$1.chapters.txt" ]; then
		movieFileNoExt=`echo $movieFile | sed 's|.m4v$||'`
		cp "${folderPath}/$1.chapters.txt" "${outputDir}/${movieFileNoExt}.chapters.txt"
		"$mp4chapsPath" -i "${outputDir}/${movieFile}"
		if [ -e "${outputDir}/${movieFileNoExt}.chapters.txt" ]; then
			rm "${outputDir}/${movieFileNoExt}.chapters.txt"
		fi
	else
		echo "No Chapter File Found"
	fi
	echo ""
}

addMetaTags() # Adds HD Flag, cnid num and videoKind for iTunes
{
	HDSD="$1"
	cnIDnum=$( tail -1 "$cnidFile" )
	mp4tagsPath=`verifyFindCLTool "$mp4tagsPath"`
	echo -e "\n*Adding Meta Tags to $movieFile"
	# write mp4 tags to files. videoKind: -i 9=movie, 10=tv show. cnid: -I <num>. HD Flag: -H 1.
	if [[ $HDSD = HD && ! "$videoKind" = "TV Show" ]]; then
		"$mp4tagsPath" -H 1 -I $cnIDnum -i 9 "$outputDir/$movieFile"
	elif [[ $HDSD = SD && ! "$videoKind" = "TV Show" ]]; then
		"$mp4tagsPath" -I $cnIDnum -i 9 "$outputDir/$movieFile"
	elif [[ $HDSD = HD && "$videoKind" = "TV Show" ]]; then
		"$mp4tagsPath" -H 1 -I $cnIDnum -i 10 "$outputDir/$movieFile"
	elif [[ $HDSD = SD && "$videoKind" = "TV Show" ]]; then
		"$mp4tagsPath" -I $cnIDnum -i 10 "$outputDir/$movieFile"
	elif [[ "$discType" = "DVD" && "$videoKind" = "TV Show" ]]; then
		"$mp4tagsPath" -i 10 "$outputDir/$movieFile"
	elif [[ "$discType" = "DVD" && ! "$videoKind" = "TV Show" ]]; then
		"$mp4tagsPath" -i 9 "$outputDir/$movieFile"
	fi
}

setFinderComment() # Sets the output file's Spotlight Comment to TV Show or Movie
{
	osascript -e "try" -e "set theFile to POSIX file \"$1\" as alias" -e "tell application \"Finder\" to set comment of theFile to \"$2\"" -e "end try" > /dev/null
}

addiTunesTagsMovie() # Adds iTunes style metadata to m4v files using theMovieDB.org api
{
# variables	
xpathPath=`verifyFindCLTool "$xpathPath"`
atomicParsley64Path=`verifyFindCLTool "$atomicParsley64Path"`
#discNameNoYear=`echo "$discName" | sed -e 's|\ (.*||g' -e 's|\ \-\ |:\ |g' -e 's|\&|\&amp;|g'`
discNameNoYear=`echo "$discName" | sed -e 's|\ (.*||g' -e 's|\ \-\ |:\ |g'`
# set TMDb searchTerm
searchTerm=`echo "$discNameNoYear" | sed -e 's|\ |+|g' -e "s|\'|%27|g"`
searchTermNoColin=`echo $searchTerm | sed 's|:||g'`
movieYear=`echo "$discName" | awk -F\( '{print $2}' | awk -F\) '{print $1}'`

echo -e "  Searching TMDb for ${searchTerm}... \c"
if [ ! -e "${sourceTmpFolder}/${searchTermNoColin}_tmp.xml" ]; then
	# get TMDb ID for all matches
	movieSearchXml="${sourceTmpFolder}/${searchTermNoColin}_tmp.xml"
	curl -s "http://api.themoviedb.org/2.1/Movie.search/en/xml/8d7d0edf7ec73435ea5d99d9cba9b54d/$searchTerm" > "$movieSearchXml"
	tmdbSearch=`"$xpathPath" "$movieSearchXml" //id 2>/dev/null | sed -e 's|\/id>|\||g'| tr '|' '\n' | awk -F\> '{print $2}' | awk -F\< '{print $1}'`

	# find the listing that matches the releses the release date, movie title and type
	for tmdbID in $tmdbSearch
	do
		# download each id to tmp.xml
		movieData="${sourceTmpFolder}/${tmdbID}_tbdb_tmp.xml"
		if [ ! -e "$movieData" ]; then
			curl -s "http://api.themoviedb.org/2.1/Movie.getInfo/en/xml/8d7d0edf7ec73435ea5d99d9cba9b54d/$tmdbID" > $movieData
			substituteISO88591 "$(cat "$movieData")" > "$movieData"
		fi
		# get movie title and release date
		discNameNoYearWildcard=`echo "$discNameNoYear" | sed -e 's|:|.*|g' -e 's|\&|.*|g'`
		releaseDate=`"$xpathPath" "$movieData" //released 2>/dev/null | awk -F\> '{print $2}' | awk -F\< '{print $1}' | grep "$movieYear"`
		movieTitle=`"$xpathPath" "$movieData" //name 2>/dev/null | awk -F\> '{print $2}' | awk -F\< '{print $1}' | sed "s|&apos;|\'|g" | egrep -ix "$discNameNoYearWildcard"`
		if [ "$movieTitle" = "" ]; then
			movieTitle=`"$xpathPath" "$movieData" //alternative_name 2>/dev/null | awk -F\> '{print $2}' | awk -F\< '{print $1}' | sed "s|&apos;|\'|g" | egrep -ix "$discNameNoYearWildcard"`
		fi

		# verify data match, delete if not a match
		if [[ ! "$releaseDate" = "" && ! "$movieTitle" = "" ]] ; then
			echo "Title found"
			mv -f "$movieData" "$movieSearchXml"
			break 1
		else
			if [ -e "$movieData" ]; then
				rm "$movieData"
			fi
		fi
	done
	if [ ! -e "$movieSearchXml" ]; then
		echo " " > "$movieSearchXml"
	fi
fi

# set metadata variables and write tags to file
if grep "<name>" "$movieSearchXml" > /dev/null ; then
	movieData="$movieSearchXml"
	substituteISO88591 "$(cat "$movieData")" > "$movieData"	
	movieTitle=`"$xpathPath" "$movieData" //name 2>/dev/null | awk -F\> '{print $2}' | awk -F\< '{print $1}' | sed -e 's|: | - |g' -e "s|&apos;|\'|g" -e 's|\&amp;|\&|g'`
	videoType=`"$xpathPath" "$movieData" "//type" 2>/dev/null | awk -F\> '{print $2}' | awk -F\< '{print $1}'`
	movieDirector=`"$xpathPath" "$movieData" "//person[@job='Director']/@name" 2>/dev/null | sed 's| name="||g' | tr '\"' '\n' | sed -e '/./!d' -e 's|^|<string>|g' -e 's|^|<dict><key>name</key>|g' -e 's|$|</string></dict>|g'`
	movieProducers=`"$xpathPath" "$movieData" "//person[@job='Executive Producer']/@name|//person[@job='Producer']/@name" 2>/dev/null | sed 's| name="||g' | tr '\"' '\n' | sed -e '/./!d' -e 's|^|<string>|g' -e 's|^|<dict><key>name</key>|g' -e 's|$|</string></dict>|g'`
	movieWriters=`"$xpathPath" "$movieData" "//person[@job='Screenplay']/@name" 2>/dev/null | sed 's| name="||g' | tr '\"' '\n' | sed -e '/./!d' -e 's|^|<string>|g' -e 's|^|<dict><key>name</key>|g' -e 's|$|</string></dict>|g'`
	movieActors=`"$xpathPath" "$movieData" "//person[@job='Actor']/@name" 2>/dev/null | sed 's| name="||g' | tr '\"' '\n' | sed -e '/./!d' -e 's|^|<string>|g' -e 's|^|<dict><key>name</key>|g' -e 's|$|</string></dict>|g'`
	albumArtists=`"$xpathPath" "$movieData" "//person[@job='Actor']/@name" 2>/dev/null | sed -e 's| name="||g' -e 's|"|, |g' -e '/./!d' -e 's|, $||'`
	releaseDate=`"$xpathPath" "$movieData" //released 2>/dev/null | awk -F\> '{print $2}' | awk -F\< '{print $1}'`
	movieDesc=`"$xpathPath" "$movieData" //overview 2>/dev/null | awk -F\> '{print $2}' | awk -F\< '{print $1}'`
	genreList=`"$xpathPath" "$movieData" "//category[@type='genre']/@name" 2>/dev/null | sed 's| name="||g' | tr '\"' '\n' | sed -e '/./!d' -e 's|^|<string>|g' -e 's|^|<dict><key>name</key>|g' -e 's|$|</string></dict>|g'`
	purchaseDate=`date "+%Y-%m-%d %H:%M:%S"`
	releaseYear=`echo "$releaseDate" | sed 's|-.*||g'`

	# parse category info and convert into iTunes genre
	if echo "$genreList" | grep 'Animation' > /dev/null ; then
		movieGenre="Kids & Family"
	elif echo "$genreList" | grep '\(Fantasy\|Science\|Science Fiction\)' > /dev/null ; then
		movieGenre="Sci-Fi & Fantasy"
	elif echo "$genreList" | grep 'Horror' > /dev/null ; then
		movieGenre="Horror"
	elif echo "$genreList" | grep '\(Action\|Adventure\|Disaster\)' > /dev/null ; then
		movieGenre="Action & Adventure"
	elif echo "$genreList" | grep '\(Musical\|Music\)' > /dev/null ; then
		movieGenre="Music"
	elif echo "$genreList" | grep 'Documentary' > /dev/null ; then
		movieGenre="Documentary"			
	elif echo "$genreList" | grep 'Sport' > /dev/null ; then
		movieGenre="Sports"			
	elif echo "$genreList" | grep 'Western' > /dev/null ; then
		movieGenre="Western"
	elif echo "$genreList" | grep '\(Thriller\|Suspense\)' > /dev/null ; then
		movieGenre="Thriller"
	elif echo "$genreList" | grep '\(Drama\|Historical\|Political\|Crime\|Mystery\)' > /dev/null ; then
		movieGenre="Drama"
	elif echo "$genreList" | grep '\(Comedy\|Road\)' > /dev/null ; then
		movieGenre="Comedy"
	fi 

	# check if moviePoster already exists
	moviePoster="${sourceTmpFolder}/${tmdbID}.jpg"
	if [ ! -e "$moviePoster" ] ; then
		getMoviePoster=`"$xpathPath" "$movieData" "//image[@type='poster' and @size='original']/@url | //image[@type='poster' and @size='cover']/@url | //image[@type='poster' and @size='mid']/@url" 2>/dev/null | sed 's|url="||g' | tr '"' '\n' | sed -e 's|^ ||' -e '/./!d'`
		for eachURL in $getMoviePoster
		do
			curl -s "$eachURL" > "$moviePoster"
			imgIntegrityTest=`sips -g pixelWidth "$moviePoster" | sed 's|.*[^0-9+]||'`
			wait
			if [ "$imgIntegrityTest" -gt 100 ]; then
				resizeImage "$moviePoster"
				break 1
			fi
		done
	fi

	# create movie tags reverseDNS xml file
	movieTagsXml="${sourceTmpFolder}/${tmdbID}_tags_tmp.xml"
	if [ ! -e "$movieTagsXml" ] ; then
		xmlFile="<?xml version=\"1.0\" encoding=\"UTF-8\"?><!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\"><plist version=\"1.0\"><dict><key>cast</key><array>${movieActors}</array><key>directors</key><array>${movieDirector}</array><key>screenwriters</key><array>${movieWriters}</array><key>producers</key><array>${movieProducers}</array></dict></plist>"
		echo "$xmlFile" | tr -cd '\11\12\40-\176' | "$xmllintPath" --format --output "${sourceTmpFolder}/${tmdbID}_tags_tmp.xml" - 
	fi
	movieTagsData=`cat "$movieTagsXml"`

	# write tags with atomic parsley
	echo -e "\n*Writing tags with AtomicParsley\c"
	if [[ -e "$moviePoster" && "$imgIntegrityTest" -gt 100 ]]; then
		"$atomicParsley64Path" "$outputDir/$movieFile" --overWrite --title "$discName" --artist "$albumArtists" --year "$releaseDate" --purchaseDate "$purchaseDate" --artwork "$moviePoster" --genre "$movieGenre" --description "$movieDesc" --rDNSatom "$movieTagsData" name=iTunMOVI domain=com.apple.iTunes
	else
		"$atomicParsley64Path" "$outputDir/$movieFile" --overWrite --title "$discName" --artist "$albumArtists" --year "$releaseDate" --purchaseDate "$purchaseDate" --genre "$movieGenre" --description "$movieDesc" --rDNSatom "$movieTagsData" name=iTunMOVI domain=com.apple.iTunes
		osascript -e 'tell application "Automator Runner" to activate & display alert "Error: Add Movie Tags" message "Error: Cover art failed integrity test" & Return & "No artwork was added"'
	fi	
else
	echo "Could not find a match"
fi

}

resizeImage () 
{
	sips -Z 600W600H "$1" --out "$1"  > /dev/null 2>&1
}

function substituteISO88591 () {
	returnString=`echo "$1" | sed -e 's|&#162;| cents|g' -e 's|&#163;|#|g' -e 's|&#164;|$|g' -e 's|&#165;| yen|g' -e 's|&#169;|©|g' -e 's|&#171;|"|g' -e 's|&#172;|/|g' -e 's|&#173;|-|g' -e 's|&#174;|®|g' -e 's|&#176;|º|g' -e 's|&#177;|+/-|g' -e 's|&#178;| 2|g' -e 's|&#179;| 3|g' -e 's|&#180;|^|g' -e 's|&#181;||g' -e 's|&#182;|¶|g' -e 's|&#183;|,|g' -e 's|&#184;||g' -e 's|&#185;| 1|g' -e 's|&#186;||g' -e 's|&#187;|"|g' -e 's|&#188;|1/4|g' -e 's|&#189;|1/2|g' -e 's|&#190;|3/4|g' -e 's|&#191;|!|g' -e 's|&#192;|A|g' -e 's|&#193;|A|g' -e 's|&#194;|A|g' -e 's|&#195;|A|g' -e 's|&#196;|A|g' -e 's|&#197;|A|g' -e 's|&#198;|AE|g' -e 's|&#199;|C|g' -e 's|&#200;|E|g' -e 's|&#201;|E|g' -e 's|&#202;|E|g' -e 's|&#203;|E|g' -e 's|&#204;|I|g' -e 's|&#205;|I|g' -e 's|&#206;|I|g' -e 's|&#207;|I|g' -e 's|&#208;|TH|g' -e 's|&#209;|N|g' -e 's|&#210;|O|g' -e 's|&#211;|O|g' -e 's|&#212;|O|g' -e 's|&#213;|O|g' -e 's|&#214;|O|g' -e 's|&#215;|x|g' -e 's|&#216;|O|g' -e 's|&#217;|U|g' -e 's|&#218;|U|g' -e 's|&#219;|U|g' -e 's|&#220;|U|g' -e 's|&#221;|Y|g' -e 's|&#222;||g' -e 's|&#223;|s|g' -e 's|&#224;|a|g' -e 's|&#225;|a|g' -e 's|&#226;|a|g' -e 's|&#227;|a|g' -e 's|&#228;|a|g' -e 's|&#229;|a|g' -e 's|&#230;|ae|g' -e 's|&#231;|c|g' -e 's|&#232;|e|g' -e 's|&#233;|e|g' -e 's|&#234;|e|g' -e 's|&#235;|e|g' -e 's|&#236;|i|g' -e 's|&#237;|i|g' -e 's|&#238;|i|g' -e 's|&#239;|i|g' -e 's|&#240;|th|g' -e 's|&#241;|n|g' -e 's|&#242;|o|g' -e 's|&#243;|o|g' -e 's|&#244;|o|g' -e 's|&#245;|o|g' -e 's|&#246;|o|g' -e 's|&#247;||g' -e 's|&#248;|o|g' -e 's|&#249;|u|g' -e 's|&#250;|u|g' -e 's|&#251;|u|g' -e 's|&#252;|u|g' -e 's|&#253;|y|g' -e 's|&#254;||g' -e 's|&#255;|y|g' -e 's|&#34;|?|g' -e 's|&#38;|&|g' -e 's|&#60;|<|g' -e 's|&#62;|>|g' -e 's|&#338;|OE|g' -e 's|&#339;|oe|g' -e 's|&#352;|S|g' -e 's|&#353;|s|g' -e 's|&#376;|Y|g' -e 's|&#382;|z|g' -e 's|&#710;||g' -e 's|&#732;|~|g' -e 's|&#8194;| |g' -e 's|&#8195;| |g' -e 's|&#8201;| |g' -e 's|&#8204;||g' -e 's|&#8205;||g' -e 's|&#8206;||g' -e 's|&#8207;||g' -e 's|&#8211;|-|g' -e 's|&#8212;|-|g' -e "s|&#8216;|'|g" -e "s|&#8217;|'|g" -e "s|&#8218;|'|g" -e 's|&#8220;|"|g' -e 's|&#8221;|"|g' -e 's|&#8222;|"|g' -e 's|&#8224;||g' -e 's|&#8225;||g' -e 's|&#8240;||g' -e 's|&#8249;|<|g' -e 's|&#8250;|>|g' -e 's|&#8364;|e|g'`
	echo "$returnString"
}

function get_log () {
	cat << EOF | osascript -l AppleScript
	try
	tell application "Terminal"
		set theText to history of tab 1 of window 1
		return theText
	end tell
	end try
EOF
}

#########################################################################################
# MAIN SCRIPT

# initialization functions

# get window id of Terminal session and change settings set to Pro
windowID=$(osascript -e 'try' -e 'tell application "Terminal" to set Window_Id to id of first window as string' -e 'end try')
osascript -e 'try' -e "tell application \"Terminal\" to set current settings of window id $windowID to settings set named \"Pro\"" -e 'end try'

# process args passed from main.command
parseVariablesInArgs $*

#makeFoldersForMe
sanityCheck

# find all the BD/DVD videos in the input search directory tree
searchForFilesAndFolders

# display the basic setup information
echo -e "\n- - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
echo -e "$scriptName v$scriptVers\n"
echo "  Start: `date`"
echo "  Input directory 1: $movieSearchDir"
echo "  Input directory 2: $tvSearchDir"
echo "  Output directory: $outputDir"
echo "  Use optical Drive: $opticalStatus"
echo "  Encode HD Sources: $encodeHdStatus"
echo "  Auto-add movie tags: $addTagsStatus"
echo "  Retire Existing File: $retireExistingFileStatus"
echo "  Growl me when complete: $growlMeStatus"
echo "  Use tsMuxer: $tsMuxerOverrideStatus"
echo "  Encode TV Shows between: ${minTrackTimeTV}-${maxTrackTimeTV} mins"
echo "  Encode Movies between: ${minTrackTimeMovie}-${maxTrackTimeMovie} mins"
echo "  Preferred Audio Language: $audioLanguage"
echo "  Will Encode: $encodeString"
echo ""

# display the list of videos found
if [ ! "$discList" = "" ]; then 
	echo "  WILL PROCESS THE FOLLOWING VIDEOS:"
	for eachVideoFound in $discList
	do
		processVariables "$eachVideoFound"
		echo "  ${discName} : (${videoKind})"
	done
else
	echo "  ERROR: No videos found"
	echo "  Check input search directories (\$movieSearchDir, \$tvSearchDir)"
	exit $E_BADARGS
fi
echo ""

# create tmp folder for script
tmpFolder="/tmp/batchEncode_$scriptPID"
if [ ! -e "$tmpFolder" ]; then
	mkdir "$tmpFolder"
fi

# process each BD/DVD video found
for eachVideoFound in $discList 
do
	processVariables "$eachVideoFound"

	# display: start of processing video
	echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
	echo -e "PROCESSING: $discName \n"

	# display: start of scan
	echo "*Scanning $sourceType: '$discName'"

	# sets the variables and scan commands based on source type
	trackFetchListSetup "${sourcePath}/${discName}"
	
	# counts the number of tracks in the trackFetchList
	trackCount=`echo $trackFetchList | wc -w`

	# display the track numbers of tracks which are within the time desired
	printTrackFetchList "$trackFetchList"
	
	# process each track in the track list
	for aTrack in $trackFetchList
	do
		# makes an mkv file from the HD source
		if [[ "$sourceFormat" = "HD" && ! "$sourceType" = "File" && tsMuxerOverride -eq 0 || "$sourceFormat" = "HD" && "$sourceType" = "Optical" ]]; then
			makeMKV "$audioLanguage"
		elif [[ "$sourceFormat" = "HD" && ! "$sourceType" = "File" && tsMuxerOverride -eq 1 ]]; then
			makeMetaFile "$aTrack"
			makeM2tsFile "$aTrack"
		fi
		
		# cnID Counter
		if [ ! -e "$cnidFile" ]; then
			echo "000001000" > "$cnidFile"
		fi
		nextcnID=$(printf "\n%09d" $( expr `tail -1 "$cnidFile"` + 1 ) >> "$cnidFile")
		
		# evaluates the input/output variables, selects the output setting and encodes with HandBrake
		processFiles "$sourcePath"

		# moves the final mkv files to the output folder
		if [[ -e "${folderPath}/${discName}-${aTrack}.mkv" && "$videoKind" = "TV Show" ]]; then
			mv "${folderPath}/${discName}-${aTrack}.mkv" "${outputDir}/${discName}-${aTrack}.mkv"
			setFinderComment "${outputDir}/${discName}-${aTrack}.mkv" "$videoKind"
		elif [[ -e "${folderPath}/${discName}-${aTrack}.mkv" && "$videoKind" = "Movie" ]]; then
			mv "${folderPath}/${discName}-${aTrack}.mkv" "${outputDir}/${discName}.mkv"
			setFinderComment "${outputDir}/${discName}.mkv" "$videoKind"
		fi

	done

	echo -e "\nPROCESSING COMPLETE: $discName"
	echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - -"	

	# delete source temp files
	if [ -e "$sourceTmpFolder" ]; then
		rm -rf $sourceTmpFolder
	fi

	# set color label of disc folder to green
	osascript -e "try" -e "set theFolder to POSIX file \"$folderPath\" as alias" -e "tell application \"Finder\" to set label index of theFolder to 6" -e "end try" > /dev/null

done

echo "-- End summary for $scriptName" >> $tmpFolder/growlMessageHD.txt && sleep 2

########  GROWL NOTIFICATION  ########
if [[ growlMe -eq 1 ]]; then
open -a GrowlHelperApp && sleep 5
growlMessage=$(cat $tmpFolder/growlMessageHD.txt)
growlnotify "Batch Encode" -m "$growlMessage" && sleep 5
fi

echo "  End: `date`"

# delete script temp files
if [ -e "$tmpFolder" ]; then
	rm -rf $tmpFolder
fi

# delete bash script tmp file
if [ -e /tmp/batchEncodeTmp.sh ]; then
	rm -f /tmp/batchEncodeTmp.sh
fi

# save terminal session log
theLog=`get_log`
if [ ! -z "$theLog" ]; then
	test -d "$HOME/Library/Logs/BatchRipActions" || mkdir "$HOME/Library/Logs/BatchRipActions"
	echo "$theLog" > "$HOME/Library/Logs/BatchRipActions/BatchEncode.log"
	#osascript -e 'try' -e "tell application \"Terminal\" to close window id $windowID" -e 'end try'
fi

exit 0
