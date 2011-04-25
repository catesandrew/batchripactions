#!/usr/bin/env sh

# main.command
# Batch Encode

# changes
# 20091020-1 Fixed tsMuxeR param typo.
# 20091118-2 Added AS to change appearance of Terminal Session
# 20091119-3 Added save session log
# 20091201-0 Finally got around to adding subroutine to pass variables as args to shell
# 20091203-0 Changed runScript call, was causing the script to quit early when set as a bg process
# 20091203-1 Deleted runScript and went back to write args to file, still quit early with last change
 
#  Created by Robert Yamada on 10/7/09.

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


	if [[ ! "${verboseLog}" ]]; then verboseLog=0; fi
	if [[ ! "${runBackgroundProcess}" ]]; then runBackgroundProcess=0; fi
	if [[ ! "${encodeHdSources}" ]]; then encodeHdSources=0; fi
	if [[ ! "${ignoreOptical}" ]]; then ignoreOptical=0; fi
	if [[ ! "${tvMinTime}" ]]; then tvMinTime=0; fi
	if [[ ! "${tvMaxTime}" ]]; then tvMaxTime=0; fi
	if [[ ! "${movieMinTime}" ]]; then movieMinTime=0; fi
	if [[ ! "${movieMaxTime}" ]]; then movieMaxTime=0; fi
	if [[ ! "${hbPath}" ]]; then hbPath="no selection"; fi
	if [[ ! "${tvPath}" ]]; then tvPath="no selection"; fi
	if [[ ! "${moviePath}" ]]; then moviePath="no selection"; fi
	if [[ ! "${encodePath}" ]]; then encodePath="no selection"; fi

	if [[ ! "${encodeSD}" ]]; then encodeSD=0; fi
	if [[ ! "${encode720p}" ]]; then encode720p=0; fi
	if [[ ! "${encode1080p}" ]]; then encode1080p=0; fi

	if [[ ! "${useCustomDvdArgs}" ]]; then useCustomDvdArgs=0; fi
	if [[ ! "${useCustom720pArgs}" ]]; then useCustom720pArgs=0; fi
	if [[ ! "${useCustom1080pArgs}" ]]; then useCustom1080pArgs=0; fi
	if [[ ! "${useCustomSdArgs}" ]]; then useCustomSdArgs=0; fi

	if [[ ! "${customDvdArgs}" ]]; then customDvdArgs="no selection"; fi
	if [[ ! "${custom720pArgs}" ]]; then custom720pArgs="no selection"; fi
	if [[ ! "${custom1080pArgs}" ]]; then custom1080pArgs="no selection"; fi
	if [[ ! "${customSdArgs}" ]]; then customSdArgs="no selection"; fi

	if [[ ! "${moveExistingFiles}" ]]; then moveExistingFiles=0; fi
	if [[ ! "${libraryFolder}" ]]; then libraryFolder="no selection"; fi
	if [[ ! "${retiredFolder}" ]]; then retiredFolder="no selection"; fi

	if [[ ! "${addTags}" ]]; then addTags=0; fi
	if [[ ! "${growlMe}" ]]; then growlMe=0; fi
	if [[ ! "${tsMuxerOverride}" ]]; then tsMuxerOverride=0; fi

	if [[ ! "${videoKind}" ]]; then videoKind="0"; fi
	if [[ videoKind -eq 0 ]]; then videoKind="Movie"; fi
	if [[ videoKind -eq 1 ]]; then videoKind="TV Show"; fi

	scriptPath="$HOME/Library/Automator/Batch Encode.action/Contents/Resources/batchEncode.sh"
	scriptTmpPath="/tmp/batchEncodeTmp.sh"

	# Temporarily replace spaces in paths
	moviePath=`echo "$moviePath" | tr ' ' ':'`
	tvPath=`echo "$tvPath" | tr ' ' ':'`
	encodePath=`echo "$encodePath" | tr ' ' ':'`
	hbPath=`echo "$hbPath" | tr ' ' ':'`
	videoKindOverride=`echo "$videoKind" | tr ' ' ':'`
	libraryFolder=`echo "$libraryFolder" | tr ' ' ':'`
	retiredFolder=`echo "$retiredFolder" | tr ' ' ':'`
	customDvdArgs=`echo "$customDvdArgs" | tr ' ' ':'`
	custom720pArgs=`echo "$custom720pArgs" | tr ' ' ':'`
	custom1080pArgs=`echo "$custom1080pArgs" | tr ' ' ':'`
	customSdArgs=`echo "$customSdArgs" | tr ' ' ':'`

	scriptArgs="--verboseLog $verboseLog --movieSearchDir $moviePath --tvSearchDir $tvPath --outputDir $encodePath --handBrakeCliPath $hbPath --minTrackTimeTV $tvMinTime --maxTrackTimeTV $tvMaxTime --minTrackTimeMovie $movieMinTime --maxTrackTimeMovie $movieMaxTime --encode_720p $encode720p --encode_SD $encodeSD --encode_1080p $encode1080p --encodeHdSources $encodeHdSources --ignoreOptical $ignoreOptical --growlMe $growlMe --tsMuxerOverride $tsMuxerOverride --videoKindOverride $videoKindOverride --addiTunesTags $addTags --retireExistingFile $moveExistingFiles --libraryFolder $libraryFolder --retiredFolder $retiredFolder --useCustomDvdArgs $useCustomDvdArgs --useCustom720pArgs $useCustom720pArgs --useCustom1080pArgs $useCustom1080pArgs --useCustomSdArgs $useCustomSdArgs --customDvdArgs $customDvdArgs --custom720pArgs $custom720pArgs --custom1080pArgs $custom1080pArgs --customSdArgs $customSdArgs"
	
	if [[ runBackgroundProcess -eq 1 ]]; then
		"$scriptPath" "$scriptArgs" &
	else
		echo "\"$scriptPath\" \"$scriptArgs\"" > "$scriptTmpPath"
		chmod 777 "$scriptTmpPath"
		open -a Terminal "$scriptTmpPath"
	fi
	
	exit 0