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
# 10-????????-0 - improved compatibility with MakeMKV
# 11-????????-1 - general fixes
# 12-????????-2 - fixed parsing of custom args
# 13-????????-3 - added support for BDSup2Sub
# 14-20101114-0 - added audio language support

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


#########################################################################################
# globals

######### CONST GLOBAL VARIABLES #########
scriptName=`basename "$0"`
scriptVers="1.0.5"
scriptPID=$$
E_BADARGS=65

######### USER DEFINED VARIABLES #########

# SET INPUT/OUTPUT PATHS
movieSearchDir="$HOME/Movies/Batch Rip Movies" # set the movie search directory 
tvSearchDir="$HOME/Movies/Batch Rip TV"		   # set the tv show search directory 
outputDir="$HOME/Movies/Batch Encode"		   # set the output directory 
cnidFile="$HOME/Library/Automator/Batch Encode.action/Contents/Resources/cnID.txt"

# SET DEFAULT TOOL PATHS
handBrakeCliPath="/usr/local/bin/HandBrakeCLI"
makemkvconPath="/Applications/MakeMKV.app/Contents/MacOS/makemkvcon" # path to makemkvcon
mkvextractPath="/usr/local/bin/mkvextract"				# path to mkvextract
mkvinfoPath="/usr/local/bin/mkvinfo"					# path to mkvinfo
mkvmergePath="/usr/local/bin/mkvmerge"					# path to mkvmerge
mp4tagsPath="/usr/local/bin/mp4tags"					# path to mp4tags
mp4chapsPath="/usr/local/bin/mp4chaps"					# path to mp4chaps
mp4artPath="/usr/local/bin/mp4art"						# path to mp4art
xpathPath="/usr/bin/xpath"								# path to xpath
xmllintPath="/usr/bin/xmllint"							# path to xmllint
atomicParsley64Path="/usr/local/bin/AtomicParsley64"    # path to AtomicParsley64
growlNotifyPath="/usr/local/bin/growlnotify"			# path to growlNofify
bdSup2SubPath="/Applications/BDSup2Sub.jar"				# path to BDSup2Sub.jar

# SET PREFERRED AUDIO LANGUAGE
nativeLanguage="eng" # set as an iso639-2 code: eng, spa, fra, etc.
useTracksDefaultAudioLanguage="0" # if set to 1 will use the tracks default audio language instead of preferred

# SET MIN AND MAX TRACK TIME
minTrackTimeTV="20"	    # this is in minutes
maxTrackTimeTV="120"	# this is in minutes
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

custom1080pArgs="noarrgs"		# set custom args if you set useCustom1080pArgs to 1
custom720pArgs="noarrgs"		# set custom args if you set useCustom720pArgs to 1
customSdArgs="noarrgs"			# set custom args if you set useCustomSdArgs to 1
customDvdArgs="noarrgs"			# set custom args if you set useCustomDvdArgs to 1

# OVERRIDE SCRIPT DEFAULT SETTINGS. (Not recommended for the less advanced)
encodeHdSources="0" 		# if set to 0, will only encode VIDEO_TS (DVDs)
skipDuplicates="1"			# if set to 0, the new output files will overwrite existing files
ignoreOptical="1"			# if set to 0, will attempt to use any mounted optical disc as a source
growlMe="0"                 # if set to 1, will use growlNotify to send encode message
videoKindOverride="Movie"   # set to TV Show or Movie for missing variable using disc input
toolArgOverride="noarrgs"   # set custom args if you set overrideProcessToolArgs to 1
makeFoldersForMe="0"		# if set to 1, will create input & output folders if they don't exist
verboseLog="0"			    # increases verbosity and saves to ~/Library/Logs/BatchRipActions
keepMkvTempFile="0"			# if set to 0, will delete the mkv temp file

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
			( --makemkvPath ) makemkvPath=$2
			shift ;;
			( --mkvtoolnixPath ) mkvtoolnixPath=$2
			shift ;;
			( --bdSup2SubPath ) bdSup2SubPath=$2
			shift ;;
			( --minTrackTimeTV ) minTrackTimeTV=$2
			shift ;;
			( --maxTrackTimeTV ) maxTrackTimeTV=$2
			shift ;;
			( --minTrackTimeMovie ) minTrackTimeMovie=$2
			shift ;;
			( --maxTrackTimeMovie ) maxTrackTimeMovie=$2
			shift ;;
			( --nativeLanguage ) nativeLanguage=$2
			shift ;;
			( --useDefaultAudioLanguage ) useTracksDefaultAudioLanguage=$2
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

	# fix spaces in paths & custom tool args
	movieSearchDir=`echo "$movieSearchDir" | tr ':' ' '`
	tvSearchDir=`echo "$tvSearchDir" | tr ':' ' '`
	outputDir=`echo "$outputDir" | tr ':' ' '`
	handBrakeCliPath=`echo "$handBrakeCliPath" | tr ':' ' '`
	makemkvconPath=`echo "$makemkvPath" | tr ':' ' ' | sed 's|$|/Contents/MacOS/makemkvcon|'`
	mkvextractPath=`echo "$mkvtoolnixPath" | tr ':' ' ' | sed 's|$|/Contents/MacOS/mkvextract|'`
	mkvinfoPath=`echo "$mkvtoolnixPath" | tr ':' ' ' | sed 's|$|/Contents/MacOS/mkvinfo|'`
	mkvmergePath=`echo "$mkvtoolnixPath" | tr ':' ' ' | sed 's|$|/Contents/MacOS/mkvmerge|'`
	bdSup2SubPath=`echo "$bdSup2SubPath" | tr ':' ' '`
	videoKindOverride=`echo "$videoKindOverride" | tr ':' ' '`
	libraryFolder=`echo "$libraryFolder" | tr ':' ' '`
	retiredFolder=`echo "$retiredFolder" | tr ':' ' '`
	customDvdArgs=`echo "$customDvdArgs" | tr '@' ' '`
	custom720pArgs=`echo "$custom720pArgs" | tr '@' ' '`
	custom1080pArgs=`echo "$custom1080pArgs" | tr '@' ' '`
	customSdArgs=`echo "$customSdArgs" | tr '@' ' '`

	# set subtitle language, BDSub2Sup requires ISO639-1 (2 char code)
	convertToISO6391 "$nativeLanguage"

}

makeFoldersForMe() # Creates input/output folders
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
		toolList="$toolList|$makemkvconPath|$mkvinfoPath|$mkvextractPath|$mkvmergePath"
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
	
	if [[ $encodeHdSources -eq 1 && ! -e "$bdSup2SubPath" ]]; then
		toolName=`basename "$bdSup2SubPath"`
		echo "    ERROR: $toolName could not be found"
		echo "    ERROR: $toolName can be installed in /Applications/"
		echo ""
		errorLog=1
	fi
	
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
	# spaces in file path temporarily become /007 and paths are divided with spaces
	discSearch=`df -T udf | grep "Volumes" | awk -F\ / {'print $2'} | sed 's|^|\/|g'` # all discs
	discString=`echo "$discSearch" | sed 's|.*|"&"|' | tr '\n' ' '`
	
	# get device name of optical drives. Need to sort by device name to get disc:<num> for makeMKV 
	deviceList=`ioreg -iSr -w 0 -c IODVDBlockStorageDevice | grep "Device Characteristics" | sed -e 's|.*"Product Name"="||' -e 's|".*||' | grep -n "" `
	
	if [[ ignoreOptical -eq 0 && ! -z "$discSearch" ]]; then
		# searches movie/tv folders and optical discs
		if [[ encodeHdSources -eq 1 ]]; then
			# searches for folders/optical drives for BDs and DVDs; searches folders for mkv, avi, m2ts, mp4, m4v, mpg and mov files
			discListCmd="find \"$movieSearchDir\" \"$tvSearchDir\" \( -maxdepth 1 -type f -name *.mkv -or -name *.avi -or -name *.m2ts -or -name *.mp4 -or -name *.m4v -or -name *.mpg -or -name *.mov \) | tr ' ' '\007' | tr '\000' ' ' & find \"$movieSearchDir\" \"$tvSearchDir\" $discString \( -type d -name BDMV -o -type d -name VIDEO_TS \) | tr ' ' '\007' | tr '\000' ' '"
			discList=`eval $discListCmd`
		else
			# searches for folders/optical drives for DVDs only; searches folders for mkv, avi, m2ts, mp4, m4v, mpg and mov files
			discListCmd="find \"$movieSearchDir\" \"$tvSearchDir\" \( -maxdepth 1 -type f -name *.mkv -or -name *.avi -or -name *.m2ts -or -name *.mp4 -or -name *.m4v -or -name *.mpg -or -name *.mov \) | tr ' ' '\007' | tr '\000' ' ' & find \"$movieSearchDir\" \"$tvSearchDir\" $discString -type d -name VIDEO_TS | tr ' ' '\007' | tr '\000' ' '"
			discList=`eval $discListCmd`
		fi
	else
		# searches movie/tv folders only; ignores optical
		if [[ encodeHdSources -eq 1 ]]; then
			# searches for folders for BDs and DVDs; searches folders for mkv, avi, m2ts, mp4, m4v, mpg and mov files
			discList=`find "$movieSearchDir" "$tvSearchDir" \( -maxdepth 1 -type f -name *.mkv -or -name *.avi -or -name *.m2ts -or -name *.mp4 -or -name *.m4v -or -name *.mpg -or -name *.mov \)  | tr ' ' '\007' | tr '\000' ' ' & find "$movieSearchDir" "$tvSearchDir" \( -type d -name BDMV -o -type d -name VIDEO_TS \) | tr ' ' '\007' | tr '\000' ' '`
		else
			# searches for folders for DVDs only; searches folders for mkv, avi, m2ts, mp4, m4v, mpg and mov files
			discList=`find "$movieSearchDir" "$tvSearchDir" \( -maxdepth 1 -type f -name *.mkv -or -name *.avi -or -name *.m2ts -or -name *.mp4 -or -name *.m4v -or -name *.mpg -or -name *.mov \)  | tr ' ' '\007' | tr '\000' ' ' & find "$movieSearchDir" "$tvSearchDir" -type d -name VIDEO_TS | tr ' ' '\007' | tr '\000' ' '`
		fi
	fi
	
	# sets encode string for setup info
	encodeBd=$(echo "$discList" | grep "BDMV")
	encodeDvd=$(echo "$discList" | grep "VIDEO_TS")
	if [[ ! "$encodeDvd" = "" || useCustomDvdArgs -eq 1 ]]; then
		if [[ useCustomDvdArgs -eq 1 ]]; 
			then encodeString="${encodeString} CUSTOM/DVD"
			else encodeString="${encodeString} SD/DVD"
		fi
	fi
	if [ ! "$encodeBd" = "" ]; then
		encodeString="${encodeString} MKV/1080p"
	fi
	if [[ "$encode_1080p" -eq 1 ]]; then
		if [[ useCustom1080pArgs -eq 1 ]]; 
			then encodeString="${encodeString} CUSTOM/1080p"
			else encodeString="${encodeString} 1080p"
		fi
	fi
	if [[ "$encode_720p" -eq 1 ]]; then
		if [[ useCustom720pArgs -eq 1 ]]; 
			then encodeString="${encodeString} CUSTOM/720p"
			else encodeString="${encodeString} 720p"
		fi		
	fi
	if [[ "$encode_SD" -eq 1 ]]; then
		if [[ useCustomSdArgs -eq 1 ]]; 
			then encodeString="${encodeString} CUSTOM/SD"
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

	# get use useTracksDefaultAudioLanguage setting for setup info
	if [[ "$useTracksDefaultAudioLanguage" -eq 0 ]]; 
		then defaultAudioStatus="No"
		else defaultAudioStatus="Yes"
	fi
}

processVariables() # Sets the script variables used for each source
{
	# correct the tmp char back to spaces in the disc file paths
	pathToSource=`echo $1 | tr '\007' ' '`
	tmpDiscPath=`dirname "$pathToSource"`
	tmpDiscName=`basename "$tmpDiscPath"`
	
	# get discPath, discName, sourceType, etc
	if echo "$discSearch" | grep "$tmpDiscPath" > /dev/null ; then
		sourceType="Optical"
		sourcePath=`dirname "$pathToSource"`
		discName=`basename "$sourcePath"`
		deviceName=`diskutil info "$sourcePath" | grep "Device / Media Name:" | sed 's|.* ||'`
		deviceNum=`echo "$deviceList" | grep "$deviceName" | awk -F: '{print $1-1}'`
	elif echo "$pathToSource" | egrep -i '(BDMV|VIDEO_TS)' > /dev/null; then
		sourceType="Folder"
		sourcePath=`dirname "$pathToSource"`
		discName=`basename "$sourcePath"`
	elif echo "$pathToSource" | egrep -i '(m2ts|mkv|avi|mp4|m4v|mpg|mov)' > /dev/null ; then
		fileExt=`basename "$pathToSource" | sed 's|.*\.||g'`
		discName=`basename "$pathToSource" .$fileExt`
		sourceFileName=`basename "$pathToSource"`
		sourcePathContainer=`dirname "$pathToSource"`
		sourcePath="${sourcePathContainer}/${discName}/${sourceFileName}"
		if [ ! -e "$sourcePath" ]; then
			mkdir "${sourcePathContainer}/${discName}"
			mv "$pathToSource" "$sourcePath"
		fi
		sourceType="File"
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
	if [ "$sourceType" = "File" ]; then
		if [ "$fileExt" = "mkv" ]; then
			scanFileCmd="\"$mkvinfoPath\" \"$sourcePath\""
			scanFile=`eval $scanFileCmd`
			sourcePixelWidth=`echo "$scanFile" | sed 's|\| *||' | tr '\n' '|' | sed 's|\|+ A track|%|g' | tr '%' '\n' | sed -e 's|^\|+ ||' -e 's|\|+|,|g' | egrep ".*Track type: video" | sed -e 's|.*Pixel width: ||' -e 's|,.*||'`
			sourcePixelHeight=`echo "$scanFile" | sed 's|\| *||' | tr '\n' '|' | sed 's|\|+ A track|%|g' | tr '%' '\n' | sed -e 's|^\|+ ||' -e 's|\|+|,|g' | egrep ".*Track type: video" | sed -e 's|.*Pixel height: ||' -e 's|,.*||'`			
		else
			scanFileCmd="\"$handBrakeCliPath\" -i \"$sourcePath\" -t0 /dev/null 2>&1"
			scanFile=`eval $scanFileCmd`
			sourcePixelWidth=`echo "$scanFile" | egrep "\+ size" | sed -e 's|^.*\+ size: ||' -e 's|x.*||'`
			sourcePixelHeight=`echo "$scanFile" | egrep "\+ size" | sed -e 's|^.*\+ size: ||' -e 's|, pixel.*||' -e 's|.*x||'`
		fi
		if [[ "$sourcePixelWidth" -gt "1279" || "$sourcePixelHeight" -gt "719" ]]; then
			sourceFormat="HD"
		else
			sourceFormat="DVD"
		fi
	fi

	if [ -e "$sourcePath/BDMV" ]; then
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
		if [ "$sourceType" = "File" ]; then
			folderPath=`dirname "$sourcePath"`
		else
			folderPath="$sourcePath"
		fi
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
	# sets the path for info file
	if [ "$sourceType" = "File" ]; then
		outFile="${folderPath}/${discName}"
	elif [[ "$sourceType" = "Optical" && "$sourceFormat" = "DVD" ]]; then
		outFile="${sourceTmpFolder}/${discName}"
	else
		outFile="$1"
	fi
	
	handBrakeCliPath=`verifyFindCLTool "$handBrakeCliPath"`
	# Set scan command and track info
	if [[ "$sourceType" = "File" && ! "$fileExt" = "mkv" || "$sourceFormat" = "DVD" ]]; then
		scanCmd="\"$handBrakeCliPath\" -i \"$sourcePath\" -t 0 /dev/null 2>&1"
		trackInfo=`eval $scanCmd`
		# save HB scan info
		if [ ! -e "${outFile}_titleInfo.txt" ]; then
			echo "$trackInfo" | egrep '[ \t]*\+' > "${outFile}_titleInfo.txt"
		fi
	elif [[ "$sourceType" = "File" && "$fileExt" = "mkv" ]]; then
		scanCmd="\"$mkvinfoPath\" \"$sourcePath\""
		trackInfo=`eval $scanCmd`
		if [ ! -e "${outFile}_titleInfo.txt" ]; then
			echo "$trackInfo" | egrep '[ \t]*\+' > "${outFile}_titleInfo.txt"
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
	#	Three input arguments are are needed. 
	#	arg1 is the minimum time in minutes selector
	#	arg2 is the maximum time in minutes selector
	#	arg3 is the raw text stream from the track 0 call to HandBrake (DVD)
	#	returns: a list of track numbers of tracks within the selectors

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
	#	returns a list of titles within the min/max duration
	if [[ "$sourceFormat" = "DVD" || "$sourceType" = "File" && ! "$fileExt" = "mkv" ]] ; then
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

	elif [[ "$sourceType" = "File" && "$fileExt" = "mkv" ]]; then
		#scanFileCmd="\"$mkvinfoPath\" \"$sourcePath\""
		#scanFile=`eval $scanFileCmd`
		aReturn=`echo "$allTrackText" | sed 's|\| *||' | tr '\n' '|' | sed 's|\|+ A track|%|g' | tr '%' '\n' | sed -e 's|^\|+ ||' -e 's|\|+|,|g' | egrep ".*Track type: video" | sed -e 's|^Track number: ||' -e 's|,.*||'`
		
	#	parse track info for BD optical disc and folder input
	#	gets a list of tracks added by makemkv
	elif [[ "$sourceFormat" = "HD" ]]; then
		makemkvconPath=`verifyFindCLTool "$makemkvconPath"`
		minTimeSecs=$[$minTime*60]
		if [ "$sourceType" = "Folder" ]; then
			trackList=`"$makemkvconPath" -r --minlength=$minTimeSecs info file:"$sourcePath" | egrep 'TINFO\:.,9,0'`
		elif [ "$sourceType" = "Optical" ]; then
			trackList=`"$makemkvconPath" -r --minlength=$minTimeSecs info disc:$deviceNum | egrep 'TINFO\:.,9,0'`
		fi
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
	fi

	#if [[ "$aReturn" = "" && "$fileExt" = "mkv" ]]; then
		#	get mkv info
		#mkvInfoCmd="\"$mkvinfoPath\" \"$sourcePath\""
		#mkvInfo=`eval $mkvInfoCmd`
		#aReturn="1"
	#fi
	
	# returns the final list of titles to be encoded
	echo "$aReturn"
}

printTrackFetchList() # Prints the tracks to encode for each source
{
	if [ ! -z "$1" ]; then
		echo "  Will encode the following tracks: `echo $1 | sed 's/ /, /g'` "
	else
		echo "  No tracks found between the min/max duration settings"
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

makeMKV() # Makes an mkv from an HD source. Extracts main audio, video, and subs.
{
	# verifies cli tool paths
	makemkvconPath=`verifyFindCLTool "$makemkvconPath"`
	mkvinfoPath=`verifyFindCLTool "$mkvinfoPath"`
	mkvmergePath=`verifyFindCLTool "$mkvmergePath"`
	mkvextractPath=`verifyFindCLTool "$mkvextractPath"`
	bdSup2SubPath=`verifyFindCLTool "$bdSup2SubPath"`
	
	# sets the file path input for mkvtoolnix
	if [ "$sourceType" = "File" ]; then
		# for files, the tmp file is the source file
		tmpFile="$sourcePath"
	else
		# for folders and discs, the tmp file is the file created by makemkv
		tmpFile="${folderPath}/title0${aTrack}.mkv"
	fi
	
	# mkvmerge will create this file for input into handbrake
	outFile="${folderPath}/${discName}-${aTrack}.mkv"

	#	CREATE MKV FROM SOURCE FILE
	#	uses makeMKV to create mkv file from selected track
	#	makemkvcon includes all languages and subs, no way to exclude unwanted items
	echo -en "${discName}-${aTrack}.mkv\nEncoded:" `date "+%l:%M %p"` "\c" >> $tmpFolder/growlMessageHD.txt &
	if [[ "$sourceType" = "Folder" || "$sourceType" = "Optical" ]]; then
		echo "*Creating MKV temp file of Track: ${aTrack}"
		if [ ! -e "$tmpFile" ]; then
			if [[ verboseLog -eq 0 ]]; then
				if [ "$sourceType" = "Folder" ]; then
					cmd="\"$makemkvconPath\" mkv --messages=-null --progress=${sourceTmpFolder}/${aTrack}-makemkv.txt file:\"$folderPath\" $aTrack \"$folderPath\""
				elif [ "$sourceType" = "Optical" ]; then
					cmd="\"$makemkvconPath\" mkv --messages=-null --progress=${sourceTmpFolder}/${aTrack}-makemkv.txt --decrypt disc:$deviceNum $aTrack \"$folderPath\""
				fi
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
			elif [[ verboseLog -eq 1 ]]; then
				if [ "$sourceType" = "Folder" ]; then
					cmd="\"$makemkvconPath\" mkv --progress=-same file:\"$folderPath\" $aTrack \"$folderPath\""
				elif [ "$sourceType" = "Optical" ]; then
					cmd="\"$makemkvconPath\" mkv --progress=-same disc:$deviceNum $aTrack \"$folderPath\""
				fi
				eval $cmd
			fi
		else
			echo "  Skipped because file already exists"
		fi
	fi
	
	#	GET AUDIO TRACK INFO
	#	uses mkvInfo to select correct audio track/language
	if [[ -e "$tmpFile" && ! -e "$outFile" ]]; then
		#	get mkv info
		mkvInfoCmd="\"$mkvinfoPath\" \"$tmpFile\""
		mkvInfo=`eval $mkvInfoCmd`
		#	get default audio track info
		defaultAudioInfo=`echo "$mkvInfo" | sed 's|\| *||' | tr '\n' '|' | sed 's|\|+ A track|%|g' | tr '%' '\n' | sed -e 's|^\|+ ||' -e 's|\|+|,|g' | egrep ".*Track type: audio" | egrep ".*Default flag: 1"`
		#	set preferred track language, track's default language or nativeLanguage
		if [ "$useTracksDefaultAudioLanguage" = "1" ]; then
			trackLanguage=$(echo "$defaultAudioInfo" | sed -e 's|.*Language: ||' -e 's|,.*||')
		else
			trackLanguage="$nativeLanguage"
		fi
		#	get audio tracks by trackLanguage
		audioInfo=`echo "$mkvInfo" | sed 's|\| *||' | tr '\n' '|' | sed 's|\|+ A track|%|g' | tr '%' '\n' | sed -e 's|^\|+ ||' -e 's|\|+|,|g' | egrep ".*Track type: audio" | egrep ".*Language: $trackLanguage"`
		#	test whether tracks with the selected language are found
		if [ "$audioInfo" = "" ]; then
			#	if it doesn't, fall back to default language
			trackLanguage=$(echo "$defaultAudioInfo" | sed -e 's|.*Language: ||' -e 's|,.*||')
			audioInfo=`echo "$mkvInfo" | sed 's|\| *||' | tr '\n' '|' | sed 's|\|+ A track|%|g' | tr '%' '\n' | sed -e 's|^\|+ ||' -e 's|\|+|,|g' | egrep ".*Track type: audio" | egrep ".*Language: $trackLanguage"`
			#	test again
			if [ "$audioInfo" = "" ]; then
				#	if it fails again, get all audio tracks and set language to unknown
				audioInfo=`echo "$mkvInfo" | sed 's|\| *||' | tr '\n' '|' | sed 's|\|+ A track|%|g' | tr '%' '\n' | sed -e 's|^\|+ ||' -e 's|\|+|,|g' | egrep ".*Track type: audio"`
				trackLanguage="unknown"
			fi
		fi
		#	search audio tracks for dts or ac-3 audio, multi-ch preferred
		dtsAc3Test=`echo "$audioInfo" | egrep '(A_DTS|A_AC3)' | egrep '.*Name: 3/2\+1'`
		if [ ! "$dtsAc3Test" = "" ]; then
			#	if found, get the track info
			getCodec=$(echo "$dtsAc3Test" | sed -e 's|^.*Codec ID: ||' -e 's|,.*||')
			getCodec1Line=$(echo "$getCodec" | tr '\n' ' ' | grep "A_DTS" | grep "A_AC3")
			if [ ! "$getCodec1Line" = "" ]; then
				#	gets the codec and the track number
				audioCodec=$(echo "$getCodec" | egrep -m2 '(A_DTS|A_AC3)' | tr '\n' '/' | sed 's|/$||')
				audioTrack=$(echo "$dtsAc3Test" | egrep -m2 '(A_DTS|A_AC3)' | sed -e 's|^Track number: ||' -e 's|,.*||' | tr '\n' ',' | sed 's|,$||')
			#	FIX for when 2 Tracks Are Present
			elif [ `echo "$getCodec" | grep -m1 "A_DTS"` ];
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
		#	provide feedback when track language is different than the native language
		if [ ! "$trackLanguage" = "$nativeLanguage" ]; then
			echo ""
			echo -e "*Preferred Audio Track: $nativeLanguage NOT FOUND"
			echo -e "  Will use Default Audio Track: ${audioTrack}: ${audioCodec}-${trackLanguage}"
		fi
		echo ""
		
		#	EXTRACT AND COVERT PGS SUBTITLES TO VOBSUBS
		#	test whether pgs subs exist in source file
		if [[ `echo "$mkvInfo" | grep "S_HDMV/PGS"` ]]; then
			#	create temporary folder for subtitle files
			subtitleTmpFolder="${sourceTmpFolder}/title0${aTrack}"
			if [ ! -e "$subtitleTmpFolder" ]; then
				mkdir "$subtitleTmpFolder"
			fi
			#	get the PGS subtitle tracks that match the native language
			getSubTracks=`echo "$mkvInfo" | sed 's|\| *||' | tr '\n' '|' | sed 's|\|+ A track|%|g' | tr '%' '\n' | sed -e 's|^\|+ ||' -e 's|\|+|,|g' | egrep ".*Codec ID: S_HDMV/PGS" | sed 's|Chapter.*||g' | egrep ".*Language: $nativeLanguage" | sed -e 's|^Track number: ||' -e 's|,.*||'`
			if [ ! "$getSubTracks" = "" ]; then
				echo -e "*Extracting PGS Subtitle Tracks from temp file…"
				subTrackList=""
				#	loop through each track to build the subTrackList string for the mkvextract command
				for eachTrack in $getSubTracks
				do
					#	creates and appends the string
					subTrackList=`echo $subTrackList ${eachTrack}:\"${subtitleTmpFolder}/subtitle-${eachTrack}.sup\"`
				done
				if [[ verboseLog -eq 0 ]]; then
					# extract subtitles with mkvextract
					subTrackList="${mkvextractPath} tracks \"$tmpFile\" ${subTrackList} > ${sourceTmpFolder}/${aTrack}-mkvextract.txt"
					eval "$subTrackList" &
					cmdPID=$!
					while [ `isPIDRunning $cmdPID` -eq 1 ]; do
						cmdStatusTxt="`tail -n 1 ${sourceTmpFolder}/${aTrack}-mkvextract.txt | grep 'Progress' | sed 's|^.* |  Progress: |'`"
						if [ ! -z "$cmdStatusTxt" ]; then
							echo -n "$cmdStatusTxt"
						fi
						sleep 0.5s
					done
					if cat "${sourceTmpFolder}/${aTrack}-mkvextract.txt" | grep "100" > /dev/null ; then
						echo -n "  Progress: 100%"
					fi
					echo ""						
					wait $cmdPID
				elif [[ verboseLog -eq 1 ]]; then
					subTrackList="${mkvextractPath} tracks \"$tmpFile\" ${subTrackList}"
					eval "$subTrackList"
				fi
			fi
			
			#	CONVERT PGS SUBS TO VOBSUBS
			#	find the sup files extracted by mkvextract
			subFileList=$(find "${subtitleTmpFolder}" -name '*.sup')
			if [ ! "$subFileList" = "" ]; then
				echo -e "  Converting PGS subtitle tracks to VOBSUB…"
				# must cd into the subtitle tmp folder to input sup files
				cd "${subtitleTmpFolder}"
				echo "$subFileList" | while read eachSub
				do
					subFileName=`basename "$eachSub"`
					if [[ verboseLog -eq 0 ]]; then
						cmd="java -Xmx256m -jar \"$bdSup2SubPath\" \"$subFileName\" \"*.idx\" '/lang:$subtitleLang' '/swap+' '/res:keep' > /dev/null 2>&1"
						eval $cmd &
						cmdPID=$!
						wait $cmdPID
					elif [[ verboseLog -eq 1 ]]; then
						cmd="java -Xmx256m -jar \"$bdSup2SubPath\" \"$subFileName\" \"*.idx\" '/lang:$subtitleLang' '/swap+' '/res:keep'"
						eval $cmd
					fi
				done
				subFile=$(find "${subtitleTmpFolder}" -name '*.idx' | sed 's|.*|"&"|' | tr '\n' ' ')
				# cd back to users home shell
				cd "$HOME"
				echo ""
			fi
		fi
		
		#	MUX MAIN AUDIO, VIDEO AND VOB SUBTITLE FILES
		#	uses mkvmerge to extract main video & selected audio language track
		#	excludes other languages & PGS subtitles, creating a new mkv file
		audioTrackCount=`echo "$mkvInfo" | sed 's|\| *||' | tr '\n' '|' | sed 's|\|+ A track|%|g' | tr '%' '\n' | sed -e 's|^\|+ ||' -e 's|\|+|,|g' | egrep -c ".*Track type: audio"`
		if [[ "$audioTrackCount" -gt 1 || ! "$subFile" = "" ]]; then
			echo -e "*Muxing Main Video, Audio (${audioCodec}-${trackLanguage}) and Subtitle Tracks from temp files"
			if [[ verboseLog -eq 0 ]]; then
				if [ -z "$subFile" ]; then
					if [[ `echo "$mkvInfo" | grep "S_VOBSUB"` ]]; then
						#	if source file has VOBSUBs include all subs
						cmd="\"$mkvmergePath\" -o \"$outFile\" -a 1,$audioTrack \"$tmpFile\" > ${sourceTmpFolder}/${aTrack}-mkvmerge.txt"
					else
						#	if it doesn't, don't include subs from source file
						cmd="\"$mkvmergePath\" -o \"$outFile\" -a 1,$audioTrack -S \"$tmpFile\" > ${sourceTmpFolder}/${aTrack}-mkvmerge.txt"
					fi
				else
					cmd="\"$mkvmergePath\" -o \"$outFile\" -a 1,$audioTrack -S \"$tmpFile\" $subFile > ${sourceTmpFolder}/${aTrack}-mkvmerge.txt"
				fi
				eval $cmd &
				cmdPID=$!
				while [ `isPIDRunning $cmdPID` -eq 1 ]; do
					cmdStatusTxt="`tail -n 1 ${sourceTmpFolder}/${aTrack}-mkvmerge.txt | grep 'Progress' | sed 's|^.* |  Progress: |'`"
					if [ ! -z "$cmdStatusTxt" ]; then
						echo -n "$cmdStatusTxt"
					fi
					sleep 0.5s
				done
				if cat "${sourceTmpFolder}/${aTrack}-mkvmerge.txt" | grep "100" > /dev/null ; then
					echo -n "  Progress: 100%"
				fi
				echo ""
				wait $cmdPID
			elif [[ verboseLog -eq 1 ]]; then
				if [ -z "$subFile" ]; then
					if [[ `echo "$mkvInfo" | grep "S_VOBSUB"` ]]; then
						cmd="\"$mkvmergePath\" -o \"$outFile\" -a 1,$audioTrack \"$tmpFile\""
					else
						cmd="\"$mkvmergePath\" -o \"$outFile\" -a 1,$audioTrack -S \"$tmpFile\""
					fi
				else
					cmd="\"$mkvmergePath\" -o \"$outFile\" -a 1,$audioTrack -S \"$tmpFile\" $subFile"
				fi
				eval $cmd
			fi
			echo -e "-" `date "+%l:%M %p"` "\n" >> $tmpFolder/growlMessageHD.txt &
		fi
	else
		echo -e "-" `date "+%l:%M %p"` "\n" >> $tmpFolder/growlMessageHD.txt &
		echo -e "${discName}-${aTrack}.mkv\nSkipped because it already exists\n" >> $tmpFolder/growlMessageHD.txt &
		echo "  Skipped because file already exists"
	fi

	#CHANGE $SOURCEPATH TO $OUTFILE
	if [ -e "$outFile" ]; then
		sourcePath="$outFile"
	fi

	# deletes temp mkv file
	if [[ -e "$tmpFile" && -e "$outFile" && "$keepMkvTempFile" -eq 0 ]]; then
		if [[ ! "$sourceType" = "File" && ! "$sourceType" = "Optical" ]]; then
			rm "$tmpFile"
		fi
	fi
}

processFiles() # Passes the source file and encode settings for each output file 
{
	sourceFile="$1"
	if [ "$sourceFormat" = "HD" ]; then
		if [[ "$sourceType" = "Folder" || "$sourceType" = "Optical" ]]; then
			sourceFile="${folderPath}/${discName}-${aTrack}.mkv"
		fi
		
		if [ -e "$sourceFile" ]; then
			if [[ encode_1080p -eq 1 && "$videoKind" = "TV Show" ]] ; then
				processToolArgs "1080p" "$sourceFile"
				encodeFile "$sourceFile" "${discName}-${aTrack}.${outFileExt}" "HD"
			elif [[ encode_1080p -eq 1 && "$videoKind" = "Movie" ]] ; then
				processToolArgs "1080p" "$sourceFile"
				encodeFile "$sourceFile" "${discName}.${outFileExt}" "HD"
			fi

			if [[ encode_720p -eq 1 && "$videoKind" = "TV Show" ]] ; then
				processToolArgs "720p" "$sourceFile"
				encodeFile "$sourceFile" "${discName}-${aTrack}.${outFileExt}" "HD"
			elif [[ encode_720p -eq 1 && "$videoKind" = "Movie" ]] ; then
				processToolArgs "720p" "$sourceFile"
				encodeFile "$sourceFile" "${discName}.${outFileExt}" "HD"
			fi

			if [[ encode_SD -eq 1 && "$videoKind" = "TV Show" ]] ; then
				processToolArgs "SD" "$sourceFile"
				encodeFile "$sourceFile" "${discName}-${aTrack} 1.${outFileExt}" "SD"
			elif [[ encode_SD -eq 1 && "$videoKind" = "Movie" ]] ; then
				processToolArgs "SD" "$sourceFile"
				encodeFile "$sourceFile" "${discName} 1.${outFileExt}" "SD"
			fi
		fi

	elif [ "$sourceFormat" = "DVD" ]; then
		if [ "$videoKind" = "TV Show" ] ; then
			processToolArgs "DVD" "$sourceFile"
			encodeFile "$sourceFile" "${discName}-${aTrack}.${outFileExt}" "DVD"
		elif [ "$videoKind" = "Movie" ] ; then
			processToolArgs "DVD" "$sourceFile"
			encodeFile "$sourceFile" "${discName}.${outFileExt}" "DVD"
		fi
	fi
}

processToolArgs() # Sets HandBrake encode settings based on input/output type
{
	encodeType="$1"
	inputFile="$2"
	handBrakeCliPath=`verifyFindCLTool "$handBrakeCliPath"`
	scanFileCmd="\"$handBrakeCliPath\" -i \"$inputFile\" -t $aTrack --scan /dev/null 2>&1"
	scanFile=`eval $scanFileCmd`
	audioInfo=`echo "$scanFile" | egrep "\+ [0-9],.*$nativeLanguage.*Hz" | egrep '(DTS|AC3)' | grep "5.1" | egrep -m1 "" | sed 's|^.*\+ ||'`
	if [ "$audioInfo" = "" ]; then
		audioInfo=`echo "$scanFile" | egrep "\+ [0-9],.*$nativeLanguage.*Hz" | egrep -m1 "" | sed 's|^.*\+ ||'`
	fi
	if [ "$useTracksDefaultAudioLanguage" = "1" ]; then
		trackLanguage=`echo "$scanFile" | egrep "\+ [0-9],.*iso639-2:.*Hz" | egrep -m1 "" | sed -e 's|.*iso639-2: ||' -e 's|).*||g'`
		audioInfo=`echo "$scanFile" | egrep "\+ [0-9],.*$trackLanguage.*Hz" | egrep '(DTS|AC3)' | grep "5.1" | egrep -m1 "" | sed 's|^.*\+ ||'`
	fi
	if [ "$audioInfo" = "" ]; then
		audioInfo=`echo "$scanFile" | egrep -A 1 'audio tracks' | egrep "\+ [0-9],.*iso639-2:" | sed 's|^.*\+ ||'`
	fi

	audioCodec=$(echo $audioInfo | sed -e 's|) .*$||' -e 's|^.* (||')
	if [[ ! "$audioCodec" = "DTS" && ! "$audioCodec" = "AC3" && ! "$audioCodec" = "AAC" ]]; then
		audioCodec="UNKNOWN"
	fi
	
	#audioChannels=$(echo "$audioInfo" | sed -e 's| ch).*||' -e 's|.*(||' -e 's|\.[0-9]||')
	#if [[ "$audioChannels" -lt 3 ]]; then
		#audioCodec="AAC"
	#fi
	
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
		( DTS/1080p | AC3/1080p | AAC/1080p | UNKNOWN/1080p )	toolArgs="-e x264 -q 21.0 -a ${audioTrack},${audioTrack} -E ca_aac,copy:ac3 -B 160,160 -6 dpl2,auto -R Auto,Auto -D 0.0,0.0 -f mp4 -4 --width 1920 --maxHeight 1080 --subtitle scan --subtitle-burn --subtitle-forced scan --native-language $nativeLanguage -m -x b-adapt=2:rc-lookahead=50";;
		( DTS/720p | AC3/720p | AAC/720p | UNKNOWN/720p )		toolArgs="-e x264 -q 21.0 -a ${audioTrack},${audioTrack} -E ca_aac,copy:ac3 -B 160,160 -6 dpl2,auto -R Auto,Auto -D 0.0,0.0 -f mp4 -4 --width 1280 --maxHeight 720 --subtitle scan --subtitle-burn --subtitle-forced scan --native-language $nativeLanguage -m -x b-adapt=2:rc-lookahead=50";;
		( DTS/SD | AC3/SD | AAC/SD | UNKNOWN/SD )				toolArgs="-e x264 -q 21.0 -a ${audioTrack},${audioTrack} -E ca_aac,copy:ac3 -B 160,160 -6 dpl2,auto -R Auto,Auto -D 0.0,0.0 -f mp4 -X 480 --subtitle scan --subtitle-burn --subtitle-forced scan --native-language $nativeLanguage -m -x b-adapt=2:rc-lookahead=50";;
		( DTS/DVD | AC3/DVD | AAC/DVD | UNKNOWN/DVD )			toolArgs="-e x264 -q 20.0 -a ${audioTrack},${audioTrack} -E ca_aac,copy:ac3 -B 160,160 -6 dpl2,auto -R Auto,Auto -D 0.0,0.0 -f mp4 -4 --loose-anamorphic --subtitle scan --subtitle-burn --subtitle-forced scan --native-language $nativeLanguage --decomb --detelecine -m -x b-adapt=2:rc-lookahead=50";;
		( Custom/1080p )	toolArgs=$(echo "$custom1080pArgs" | sed -e "s|\${audioTrack}|$audioTrack|g" -e "s|\$nativeLanguage|$nativeLanguage|g");;
		( Custom/720p )		toolArgs=$(echo "$custom720pArgs" | sed -e "s|\${audioTrack}|$audioTrack|g" -e "s|\$nativeLanguage|$nativeLanguage|g");;
		( Custom/SD )		toolArgs=$(echo "$customSdArgs" | sed -e "s|\${audioTrack}|$audioTrack|g" -e "s|\$nativeLanguage|$nativeLanguage|g");;
		( Custom/DVD )		toolArgs=$(echo "$customDvdArgs" | sed -e "s|\${audioTrack}|$audioTrack|g" -e "s|\$nativeLanguage|$nativeLanguage|g");;
		( * )				toolArgs="-e x264 -q 20.0 -a ${audioTrack},${audioTrack} -E ca_aac,copy:ac3 -B 160,160 -6 dpl2,auto -R Auto,Auto -D 0.0,0.0 -f mp4 -4 --loose-anamorphic --subtitle scan --subtitle-burn --subtitle-forced scan --native-language $nativeLanguage --decomb --detelecine -m -x b-adapt=2:rc-lookahead=50";;
	esac
	
	if echo "$toolArgs" | egrep -i 'mp4' > /dev/null; then
		outFileExt="m4v"
	elif echo "$toolArgs" | egrep -i 'mkv' > /dev/null; then
		outFileExt="mkv"
	else
		outFileExt="m4v"
	fi
	
	# Set track info to print to screen
	videoTrackString=$(echo "$scanFile" | grep "+ " | egrep '(\+ duration|size)' | sed -e s'|duration|Duration|' -e 's|size|Size|' -e 's|.*+||' -e 's|,.*||' | tr '\n' ', ' | sed -e 's|,$||')
	audioTrackString=$(echo $audioInfo | sed 's|),.*$|)|')
	subtitleTrackString=`echo "$scanFile" | egrep -A 20 'subtitle tracks' | egrep "\+ [0-9],.*iso639-2:"`
	
}

encodeFile() # Encodes source with HandBrake and sends output files for further processing
{
	inputPath="$1"
	movieFile="$2"
	handBrakeCliPath=`verifyFindCLTool "$handBrakeCliPath"`
	
	if [[ ! -e  "$outputDir/$movieFile" || skipDuplicates -eq 0 ]] ; then
		echo -e "\n*Creating $movieFile"
		echo "  Video Track: $aTrack,$videoTrackString"
		echo "  Audio Track: $audioTrackString"
		echo "  Subtitle Tracks:"
		echo -e "${subtitleTrackString}\n"
		echo -e "Using ${encodeFormat}-toolArgs: ${toolArgs}\n"
		echo -en "$movieFile\nEncoded:" `date "+%l:%M %p"` "\c" >> $tmpFolder/growlMessageHD.txt &

		# encode with verbose level 0
		if [[ verboseLog -eq 0 ]]; then
			# encode cmd for BD
			if [ "$sourceFormat" = "HD" ]; then
				cmd="\"$handBrakeCliPath\" -i \"$inputPath\" -o \"${outputDir}/${movieFile}\" -v 0 $toolArgs 2>/dev/null"
			# encode cmd for DVD
			elif [ "$sourceFormat" = "DVD" ]; then
				cmd="\"$handBrakeCliPath\" -i \"$inputPath\" -t $aTrack -o \"${outputDir}/${movieFile}\" -v 0 $toolArgs 2>/dev/null"
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
			# if file is a movie and movie already exists in archive, move existing file to retired folder
			if [[ ! "$videoKind" = "TV Show" && retireExistingFile -eq 1 ]]; then
				retireExistingFile
			fi
			# adds iTunes style tags to mp4 files
			if echo "$movieFile" | grep -v "mkv" > /dev/null; then
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
	echo -e "\n*Checking if $discName exists in Movie Folder"
	# ADDED 2010-10-21
	findMovieCMD=`find "${libraryFolder}" -type d -maxdepth 1 -name "$discName*"`
	theFile=`basename "$findMovieCMD"`
	if [ -d "$findMovieCMD" ]; then
		mv "$findMovieCMD" "${retiredFolder}/${theFile}"
		if [ -d "${retiredFolder}/${theFile}" ]; then
			echo "  $discName MOVED to Retired Folder"
		else
			echo "  $discName FAILED to MOVE to Retired Folder"
		fi
	else
		echo "  $discName does NOT exist"
	fi
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

setFinderComment() # Sets Spotlight Comment of the output file to TV Show or Movie
{
	osascript -e "try" -e "set theFile to POSIX file \"$1\" as alias" -e "tell application \"Finder\" to set comment of theFile to \"$2\"" -e "tell application \"Finder\" to update theFile" -e "end try" > /dev/null
}

setFolderColor() # Sets the source folder color to green
{
	osascript -e "try" -e "set theFolder to POSIX file \"$1\" as alias" -e "tell application \"Finder\" to set label index of theFolder to 6" -e "end try" > /dev/null
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
		#changed getMoverPoster xml file variable from $movieData to $movieSearchXml on 8/20/2010
		getMoviePoster=`"$xpathPath" "$movieSearchXml" "//image[@type='poster' and @size='original']/@url | //image[@type='poster' and @size='cover']/@url | //image[@type='poster' and @size='mid']/@url" 2>/dev/null | sed 's|url="||g' | tr '"' '\n' | sed -e 's|^ ||' -e '/./!d'`
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

resizeImage () # Resizes large cover art to max 600px
{
	sips -Z 600W600H "$1" --out "$1"  > /dev/null 2>&1
}

substituteISO88591 () # Converts ISO8859-1 strings in metadata
{
	returnString=`echo "$1" | sed -e 's|&#162;| cents|g' -e 's|&#163;|#|g' -e 's|&#164;|$|g' -e 's|&#165;| yen|g' -e 's|&#169;|©|g' -e 's|&#171;|"|g' -e 's|&#172;|/|g' -e 's|&#173;|-|g' -e 's|&#174;|®|g' -e 's|&#176;|º|g' -e 's|&#177;|+/-|g' -e 's|&#178;| 2|g' -e 's|&#179;| 3|g' -e 's|&#180;|^|g' -e 's|&#181;||g' -e 's|&#182;|¶|g' -e 's|&#183;|,|g' -e 's|&#184;||g' -e 's|&#185;| 1|g' -e 's|&#186;||g' -e 's|&#187;|"|g' -e 's|&#188;|1/4|g' -e 's|&#189;|1/2|g' -e 's|&#190;|3/4|g' -e 's|&#191;|!|g' -e 's|&#192;|A|g' -e 's|&#193;|A|g' -e 's|&#194;|A|g' -e 's|&#195;|A|g' -e 's|&#196;|A|g' -e 's|&#197;|A|g' -e 's|&#198;|AE|g' -e 's|&#199;|C|g' -e 's|&#200;|E|g' -e 's|&#201;|E|g' -e 's|&#202;|E|g' -e 's|&#203;|E|g' -e 's|&#204;|I|g' -e 's|&#205;|I|g' -e 's|&#206;|I|g' -e 's|&#207;|I|g' -e 's|&#208;|TH|g' -e 's|&#209;|N|g' -e 's|&#210;|O|g' -e 's|&#211;|O|g' -e 's|&#212;|O|g' -e 's|&#213;|O|g' -e 's|&#214;|O|g' -e 's|&#215;|x|g' -e 's|&#216;|O|g' -e 's|&#217;|U|g' -e 's|&#218;|U|g' -e 's|&#219;|U|g' -e 's|&#220;|U|g' -e 's|&#221;|Y|g' -e 's|&#222;||g' -e 's|&#223;|s|g' -e 's|&#224;|a|g' -e 's|&#225;|a|g' -e 's|&#226;|a|g' -e 's|&#227;|a|g' -e 's|&#228;|a|g' -e 's|&#229;|a|g' -e 's|&#230;|ae|g' -e 's|&#231;|c|g' -e 's|&#232;|e|g' -e 's|&#233;|e|g' -e 's|&#234;|e|g' -e 's|&#235;|e|g' -e 's|&#236;|i|g' -e 's|&#237;|i|g' -e 's|&#238;|i|g' -e 's|&#239;|i|g' -e 's|&#240;|th|g' -e 's|&#241;|n|g' -e 's|&#242;|o|g' -e 's|&#243;|o|g' -e 's|&#244;|o|g' -e 's|&#245;|o|g' -e 's|&#246;|o|g' -e 's|&#247;||g' -e 's|&#248;|o|g' -e 's|&#249;|u|g' -e 's|&#250;|u|g' -e 's|&#251;|u|g' -e 's|&#252;|u|g' -e 's|&#253;|y|g' -e 's|&#254;||g' -e 's|&#255;|y|g' -e 's|&#34;|?|g' -e 's|&#38;|&|g' -e 's|&#60;|<|g' -e 's|&#62;|>|g' -e 's|&#338;|OE|g' -e 's|&#339;|oe|g' -e 's|&#352;|S|g' -e 's|&#353;|s|g' -e 's|&#376;|Y|g' -e 's|&#382;|z|g' -e 's|&#710;||g' -e 's|&#732;|~|g' -e 's|&#8194;| |g' -e 's|&#8195;| |g' -e 's|&#8201;| |g' -e 's|&#8204;||g' -e 's|&#8205;||g' -e 's|&#8206;||g' -e 's|&#8207;||g' -e 's|&#8211;|-|g' -e 's|&#8212;|-|g' -e "s|&#8216;|'|g" -e "s|&#8217;|'|g" -e "s|&#8218;|'|g" -e 's|&#8220;|"|g' -e 's|&#8221;|"|g' -e 's|&#8222;|"|g' -e 's|&#8224;||g' -e 's|&#8225;||g' -e 's|&#8240;||g' -e 's|&#8249;|<|g' -e 's|&#8250;|>|g' -e 's|&#8364;|e|g'`
	echo "$returnString"
}

convertToISO6391 () # Converts ISO639-2 (3-char) Language Code to ISO639-1 (2-char)
{
	case $nativeLanguage in ( aar ) subtitleLang="aa";; ( abk ) subtitleLang="ab";; ( afr ) subtitleLang="af";; ( aka ) subtitleLang="ak";; ( alb ) subtitleLang="sq";; ( amh ) subtitleLang="am";; ( ara ) subtitleLang="ar";; ( arg ) subtitleLang="an";; ( arm ) subtitleLang="hy";; ( asm ) subtitleLang="as";; ( ava ) subtitleLang="av";; ( ave ) subtitleLang="ae";; ( aym ) subtitleLang="ay";; ( aze ) subtitleLang="az";; ( bak ) subtitleLang="ba";; ( bam ) subtitleLang="bm";; ( baq ) subtitleLang="eu";; ( bel ) subtitleLang="be";; ( ben ) subtitleLang="bn";; ( bih ) subtitleLang="bh";; ( bis ) subtitleLang="bi";; ( bod ) subtitleLang="bo";; ( bos ) subtitleLang="bs";; ( bre ) subtitleLang="br";; ( bul ) subtitleLang="bg";; ( bur ) subtitleLang="my";; ( cat ) subtitleLang="ca";; ( ces ) subtitleLang="cs";; ( cha ) subtitleLang="ch";; ( che ) subtitleLang="ce";; ( chi ) subtitleLang="zh";; ( chu ) subtitleLang="cu";; ( chv ) subtitleLang="cv";; ( cor ) subtitleLang="kw";; ( cos ) subtitleLang="co";; ( cre ) subtitleLang="cr";; ( cym ) subtitleLang="cy";; ( cze ) subtitleLang="cs";; ( dan ) subtitleLang="da";; ( deu ) subtitleLang="de";; ( div ) subtitleLang="dv";; ( dut ) subtitleLang="nl";; ( dzo ) subtitleLang="dz";; ( ell ) subtitleLang="el";; ( eng ) subtitleLang="en";; ( epo ) subtitleLang="eo";; ( est ) subtitleLang="et";; ( eus ) subtitleLang="eu";; ( ewe ) subtitleLang="ee";; ( fao ) subtitleLang="fo";; ( fas ) subtitleLang="fa";; ( fij ) subtitleLang="fj";; ( fin ) subtitleLang="fi";; ( fra ) subtitleLang="fr";; ( fre ) subtitleLang="fr";; ( fry ) subtitleLang="fy";; ( ful ) subtitleLang="ff";; ( geo ) subtitleLang="ka";; ( ger ) subtitleLang="de";; ( gla ) subtitleLang="gd";; ( gle ) subtitleLang="ga";; ( glg ) subtitleLang="gl";; ( glv ) subtitleLang="gv";; ( gre ) subtitleLang="el";; ( grn ) subtitleLang="gn";; ( guj ) subtitleLang="gu";; ( hat ) subtitleLang="ht";; ( hau ) subtitleLang="ha";; ( heb ) subtitleLang="he";; ( her ) subtitleLang="hz";; ( hin ) subtitleLang="hi";; ( hmo ) subtitleLang="ho";; ( hrv ) subtitleLang="hr";; ( hun ) subtitleLang="hu";; ( hye ) subtitleLang="hy";; ( ibo ) subtitleLang="ig";; ( ice ) subtitleLang="is";; ( ido ) subtitleLang="io";; ( iii ) subtitleLang="ii";; ( iku ) subtitleLang="iu";; ( ile ) subtitleLang="ie";; ( ina ) subtitleLang="ia";; ( ind ) subtitleLang="id";; ( ipk ) subtitleLang="ik";; ( isl ) subtitleLang="is";; ( ita ) subtitleLang="it";; ( jav ) subtitleLang="jv";; ( jpn ) subtitleLang="ja";; ( kal ) subtitleLang="kl";; ( kan ) subtitleLang="kn";; ( kas ) subtitleLang="ks";; ( kat ) subtitleLang="ka";; ( kau ) subtitleLang="kr";; ( kaz ) subtitleLang="kk";; ( khm ) subtitleLang="km";; ( kik ) subtitleLang="ki";; ( kin ) subtitleLang="rw";; ( kir ) subtitleLang="ky";; ( kom ) subtitleLang="kv";; ( kon ) subtitleLang="kg";; ( kor ) subtitleLang="ko";; ( kua ) subtitleLang="kj";; ( kur ) subtitleLang="ku";; ( lao ) subtitleLang="lo";; ( lat ) subtitleLang="la";; ( lav ) subtitleLang="lv";; ( lim ) subtitleLang="li";; ( lin ) subtitleLang="ln";; ( lit ) subtitleLang="lt";; ( ltz ) subtitleLang="lb";; ( lub ) subtitleLang="lu";; ( lug ) subtitleLang="lg";; ( mac ) subtitleLang="mk";; ( mah ) subtitleLang="mh";; ( mal ) subtitleLang="ml";; ( mao ) subtitleLang="mi";; ( mar ) subtitleLang="mr";; ( may ) subtitleLang="ms";; ( mkd ) subtitleLang="mk";; ( mlg ) subtitleLang="mg";; ( mlt ) subtitleLang="mt";; ( mon ) subtitleLang="mn";; ( mri ) subtitleLang="mi";; ( msa ) subtitleLang="ms";; ( mya ) subtitleLang="my";; ( nau ) subtitleLang="na";; ( nav ) subtitleLang="nv";; ( nbl ) subtitleLang="nr";; ( nde ) subtitleLang="nd";; ( ndo ) subtitleLang="ng";; ( nep ) subtitleLang="ne";; ( nld ) subtitleLang="nl";; ( nno ) subtitleLang="nn";; ( nob ) subtitleLang="nb";; ( nor ) subtitleLang="no";; ( nya ) subtitleLang="ny";; ( oci ) subtitleLang="oc";; ( oji ) subtitleLang="oj";; ( ori ) subtitleLang="or";; ( orm ) subtitleLang="om";; ( oss ) subtitleLang="os";; ( pan ) subtitleLang="pa";; ( per ) subtitleLang="fa";; ( pli ) subtitleLang="pi";; ( pol ) subtitleLang="pl";; ( por ) subtitleLang="pt";; ( pus ) subtitleLang="ps";; ( que ) subtitleLang="qu";; ( roh ) subtitleLang="rm";; ( ron ) subtitleLang="ro";; ( rum ) subtitleLang="ro";; ( run ) subtitleLang="rn";; ( rus ) subtitleLang="ru";; ( sag ) subtitleLang="sg";; ( san ) subtitleLang="sa";; ( sin ) subtitleLang="si";; ( slk ) subtitleLang="sk";; ( slo ) subtitleLang="sk";; ( slv ) subtitleLang="sl";; ( sme ) subtitleLang="se";; ( smo ) subtitleLang="sm";; ( sna ) subtitleLang="sn";; ( snd ) subtitleLang="sd";; ( som ) subtitleLang="so";; ( sot ) subtitleLang="st";; ( spa ) subtitleLang="es";; ( sqi ) subtitleLang="sq";; ( srd ) subtitleLang="sc";; ( srp ) subtitleLang="sr";; ( ssw ) subtitleLang="ss";; ( sun ) subtitleLang="su";; ( swa ) subtitleLang="sw";; ( swe ) subtitleLang="sv";; ( tah ) subtitleLang="ty";; ( tam ) subtitleLang="ta";; ( tat ) subtitleLang="tt";; ( tel ) subtitleLang="te";; ( tgk ) subtitleLang="tg";; ( tgl ) subtitleLang="tl";; ( tha ) subtitleLang="th";; ( tib ) subtitleLang="bo";; ( tir ) subtitleLang="ti";; ( ton ) subtitleLang="to";; ( tsn ) subtitleLang="tn";; ( tso ) subtitleLang="ts";; ( tuk ) subtitleLang="tk";; ( tur ) subtitleLang="tr";; ( twi ) subtitleLang="tw";; ( uig ) subtitleLang="ug";; ( ukr ) subtitleLang="uk";; ( urd ) subtitleLang="ur";; ( uzb ) subtitleLang="uz";; ( ven ) subtitleLang="ve";; ( vie ) subtitleLang="vi";; ( vol ) subtitleLang="vo";; ( wel ) subtitleLang="cy";; ( wln ) subtitleLang="wa";; ( wol ) subtitleLang="wo";; ( xho ) subtitleLang="xh";; ( yid ) subtitleLang="yi";; ( yor ) subtitleLang="yo";; ( zha ) subtitleLang="za";; ( zho ) subtitleLang="zh";; ( zul ) subtitleLang="zu";; ( * ) subtitleLang="en";; esac
}

get_log () # Gets Terminal Log
{
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

# create tmp folder for script
tmpFolder="/tmp/batchEncode_$scriptPID"
if [ ! -e "$tmpFolder" ]; then
	mkdir "$tmpFolder"
fi

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
echo "  Encode TV Shows between: ${minTrackTimeTV}-${maxTrackTimeTV} mins"
echo "  Encode Movies between: ${minTrackTimeMovie}-${maxTrackTimeMovie} mins"
echo "  Native Language: $nativeLanguage ($subtitleLang)"
echo "  Use Disc's Default Audio Language: $defaultAudioStatus"
echo "  Will Encode: $encodeString"
if [[ verboseLog -eq 1 ]]; then
	echo -e "\n  - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
	echo "  VERBOSE MODE"
	echo "  - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
fi
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
		if [[ "$sourceFormat" = "HD" && "$sourceType" = "Folder" || "$sourceFormat" = "HD" && "$sourceType" = "File" && "$fileExt" = "mkv" || "$sourceFormat" = "HD" && "$sourceType" = "Optical" ]]; then
			makeMKV "$nativeLanguage"
		fi
		
		# cnID Counter
		if [ ! -e "$cnidFile" ]; then
			echo "000001000" > "$cnidFile"
		fi
		#nextcnID=$(printf "\n%09d" $( expr `tail -1 "$cnidFile"` + 1 ) >> "$cnidFile")
		nextcnID=$(printf "\n%09d" $( expr `echo $((RANDOM%999999999+3000))` ))
		#echo $((RANDOM%999999999+3000))
		# evaluates the input/output variables, selects the output setting and encodes with HandBrake
		processFiles "$sourcePath"

		# moves the final mkv files to the output folder
		if [[ -e "${folderPath}/${discName}-${aTrack}.mkv" && ! -e "${outputDir}/${discName}-${aTrack}.mkv" && "$videoKind" = "TV Show" ]]; then
			mv "${folderPath}/${discName}-${aTrack}.mkv" "${outputDir}/${discName}-${aTrack}.mkv"
			setFinderComment "${outputDir}/${discName}-${aTrack}.mkv" "$videoKind"
		elif [[ -e "${folderPath}/${discName}-${aTrack}.mkv" && ! -e "${outputDir}/${discName}.mkv" && "$videoKind" = "Movie" ]]; then
			mv "${folderPath}/${discName}-${aTrack}.mkv" "${outputDir}/${discName}.mkv"
			setFinderComment "${outputDir}/${discName}.mkv" "$videoKind"
		fi

	done

	# set color label of disc folder
	setFolderColor "$folderPath" &

	echo -e "\nPROCESSING COMPLETE: $discName"
	echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - -"

	# delete source temp files
	if [ -e "$sourceTmpFolder" ]; then
		rm -rf $sourceTmpFolder
	fi

done

echo "-- End summary for $scriptName" >> "${tmpFolder}/growlMessageHD.txt" && sleep 2

########  GROWL NOTIFICATION  ########
if [[ growlMe -eq 1 ]]; then
	test -x "$growlNotifyPath"
	open -a GrowlHelperApp && sleep 5
	growlMessage=$(cat ${tmpFolder}/growlMessageHD.txt)
	"$growlNotifyPath" "Batch Encode" -m "$growlMessage" && sleep 5
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
fi

exit 0