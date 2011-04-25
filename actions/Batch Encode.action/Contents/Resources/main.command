#!/usr/bin/env sh

# main.command
# Batch Encode

# changes
# 20091118-2 Added AS to change appearance of Terminal Session
# 20091119-3 Added save session log
# 20091201-0 Finally got around to adding subroutine to pass variables as args to shell
# 20091203-0 Changed runScript call, was causing the script to quit early when set as a bg process
# 20091203-1 Deleted runScript and went back to write args to file, still quit early with last change
# ????????-0 Fixed parsing issue of custom args
# 20101202-1 Added support for source input via Automator 
# 20101202-1 Added option to keep mkv temp file
# 20101208-0 Added tagchimp chapters
 
#  Created by Robert Yamada on 10/7/09.

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

# create application support folder
batchRipSupport="$HOME/Library/Application Support/Batch Rip"
if [ ! -d "$batchRipSupport" ]; then
	mkdir "$batchRipSupport"
fi

while read thePath
do
	thePathNoSpace=$(echo "$thePath" | tr ' ' ':' | sed -e 's|(|\(|g' -e 's|)|\)|g')
	sourceList=$(echo "$sourceList$thePathNoSpace ")
done
# set the variables
if [[ ! "${verboseLog}" ]]; then verboseLog=0; fi
if [[ ! "${runBackgroundProcess}" ]]; then runBackgroundProcess=0; fi
if [[ ! "${encodeHdSources}" ]]; then encodeHdSources=0; fi
if [[ ! "${ignoreOptical}" ]]; then ignoreOptical=0; fi
if [[ ! "${tvMinTime}" ]]; then tvMinTime=0; fi
if [[ ! "${tvMaxTime}" ]]; then tvMaxTime=0; fi
if [[ ! "${movieMinTime}" ]]; then movieMinTime=0; fi
if [[ ! "${movieMaxTime}" ]]; then movieMaxTime=0; fi
if [[ ! "${hbPath}" ]]; then hbPath="no selection"; fi
if [[ ! "${makemkvPath}" ]]; then makemkvPath="no selection"; fi
if [[ ! "${mkvtoolnixPath}" ]]; then mkvtoolnixPath="no selection"; fi
if [[ ! "${bdsup2subPath}" ]]; then bdsup2subPath="no selection"; fi
if [[ ! "${tvPath}" ]]; then tvPath="no selection"; fi
if [[ ! "${moviePath}" ]]; then moviePath="no selection"; fi
if [[ ! "${encodePath}" ]]; then encodePath="no selection"; fi

if [[ ! "${encodeDVD2}" ]]; then encodeDVD2=0; fi
if [[ ! "${encodeSD}" ]]; then encodeSD=0; fi
if [[ ! "${encode720p}" ]]; then encode720p=0; fi

if [[ ! "${presetDvd}" ]]; then presetDvd="no selection"; fi
if [[ ! "${presetDvd2}" ]]; then presetDvd2="no selection"; fi
if [[ ! "${presetSd}" ]]; then presetSd="no selection"; fi
if [[ ! "${preset720p}" ]]; then preset720p="no selection"; fi

if [[ ! "${useCustomDvdArgs}" ]]; then useCustomDvdArgs=0; fi
if [[ ! "${useCustomDvd2Args}" ]]; then useCustomDvd2Args=0; fi
if [[ ! "${useCustom720pArgs}" ]]; then useCustom720pArgs=0; fi
if [[ ! "${useCustomSdArgs}" ]]; then useCustomSdArgs=0; fi

if [[ ! "${customDvdArgs}" ]]; then customDvdArgs="no selection"; fi
if [[ ! "${customDvd2Args}" ]]; then customDvd2Args="no selection"; fi
if [[ ! "${custom720pArgs}" ]]; then custom720pArgs="no selection"; fi
if [[ ! "${customSdArgs}" ]]; then customSdArgs="no selection"; fi

if [[ ! "${moveExistingFiles}" ]]; then moveExistingFiles=0; fi
if [[ ! "${libraryFolder}" ]]; then libraryFolder="no selection"; fi
if [[ ! "${retiredFolder}" ]]; then retiredFolder="no selection"; fi

if [[ ! "${addTags}" ]]; then addTags=0; fi
if [[ ! "${growlMe}" ]]; then growlMe=0; fi
if [[ ! "${keepMkvTempFile}" ]]; then keepMkvTempFile=0; fi
if [[ ! "${audioLang}" ]]; then audioLang="eng"; fi
if [[ ! "${useDefaultAudioLanguage}" ]]; then useDefaultAudioLanguage="0"; fi

if [[ ! "${videoKind}" ]]; then videoKind="0"; fi
if [[ videoKind -eq 0 ]]; then videoKind="Movie"; fi
if [[ videoKind -eq 1 ]]; then videoKind="TV Show"; fi

scriptPath="$HOME/Library/Automator/Batch Encode.action/Contents/Resources/batchEncode.sh"
scriptTmpPath="$HOME/Library/Application Support/Batch Rip/batchEncodeTmp.sh"

# Temporarily replace spaces in paths
moviePath=`echo "$moviePath" | tr ' ' ':'`
tvPath=`echo "$tvPath" | tr ' ' ':'`
encodePath=`echo "$encodePath" | tr ' ' ':'`
hbPath=`echo "$hbPath" | tr ' ' ':'`
makemkvPath=`echo "$makemkvPath" | tr ' ' ':'`
mkvtoolnixPath=`echo "$mkvtoolnixPath" | tr ' ' ':'`
bdsup2subPath=`echo "$bdsup2subPath" | tr ' ' ':'`
videoKindOverride=`echo "$videoKind" | tr ' ' ':'`
libraryFolder=`echo "$libraryFolder" | tr ' ' ':'`
retiredFolder=`echo "$retiredFolder" | tr ' ' ':'`
customDvdArgs=`echo "$customDvdArgs" | tr ' ' '@'`
custom720pArgs=`echo "$custom720pArgs" | tr ' ' '@'`
customDvd2Args=`echo "$customDvd2Args" | tr ' ' '@'`
customSdArgs=`echo "$customSdArgs" | tr ' ' '@'`
presetDvd=`echo "$presetDvd" | tr ' ' '@'`
presetDvd2=`echo "$presetDvd2" | tr ' ' '@'`
presetSd=`echo "$presetSd" | tr ' ' '@'`
preset720p=`echo "$preset720p" | tr ' ' '@'`

scriptArgs="--verboseLog $verboseLog --movieSearchDir $moviePath --tvSearchDir $tvPath --outputDir $encodePath --handBrakeCliPath $hbPath --makemkvPath $makemkvPath --mkvtoolnixPath $mkvtoolnixPath --bdSup2SubPath $bdsup2subPath --minTrackTimeTV $tvMinTime --maxTrackTimeTV $tvMaxTime --minTrackTimeMovie $movieMinTime --maxTrackTimeMovie $movieMaxTime --nativeLanguage $nativeLanguage --useDefaultAudioLanguage $useDefaultAudioLanguage --encode_DVD2 $encodeDVD2 --encode_SD $encodeSD --encode_720p $encode720p --encodeHdSources $encodeHdSources --ignoreOptical $ignoreOptical --growlMe $growlMe --keepMkvTempFile $keepMkvTempFile --videoKindOverride $videoKindOverride --addiTunesTags $addTags --retireExistingFile $moveExistingFiles --libraryFolder $libraryFolder --retiredFolder $retiredFolder --useCustomDvdArgs $useCustomDvdArgs --useCustomDvd2Args $useCustomDvd2Args --useCustomSdArgs $useCustomSdArgs --useCustom720pArgs $useCustom720pArgs --customDvdArgs $customDvdArgs --customDvd2Args $customDvd2Args --customSdArgs $customSdArgs --custom720pArgs $custom720pArgs --presetDvd $presetDvd --presetDvd2 $presetDvd2 --presetSd $presetSd --preset720p $preset720p"

if [[ runBackgroundProcess -eq 1 ]]; then
	echo "\"$scriptPath\" \"$scriptArgs\" \"$sourceList\"" > "$scriptTmpPath"
	chmod 777 "$scriptTmpPath"
	"$scriptTmpPath"
else
	echo "\"$scriptPath\" \"$scriptArgs\" \"$sourceList\"" > "$scriptTmpPath"
	chmod 777 "$scriptTmpPath"
	open -a Terminal "$scriptTmpPath"
fi

exit 0
