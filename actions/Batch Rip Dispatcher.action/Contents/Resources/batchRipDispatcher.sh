#!/bin/sh

# batchRipDispatcher.sh
# Batch Rip Dispatcher
# Changes:
# 1-20091118 - made update current items list a function
# 2-20091118 - commands changed to run in background
# 3-20101209 - changed most functions to batch rip

# Created by Robert Yamada on 11/12/09.
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

function updateCurrentItemsList () {
	if [ -e "$currentItemsList" ]; then
		currentItemSearch=`cat "$currentItemsList" | awk -F: '{print $1}' | tr ' ' '\007' | tr '\000' ' '`
		for eachItem in $currentItemSearch
		do
			eachItem=`echo "$eachItem"  | tr '\007' ' '`
			if [ ! -d "$eachItem" ]; then
				sed -i "" "\#$eachItem#d" "$currentItemsList"
			fi
		done
	fi
}

function batchRipDispatch () {
	discSearch=`df -T udf | grep "Volumes" | awk -F\ / {'print $2'} | sed 's|^|\/|g' | tr ' ' '\007' | tr '\000' ' '`
	for eachDisc in $discSearch
	do
		eachDisc=`echo "$eachDisc"  | tr '\007' ' '`
		discType=`diskutil info "$eachDisc" | grep "Optical Media Type" | sed 's|.*: *||'`
		if [[ "$discType" = "BD-ROM" || "$discType" = "DVD-ROM" ]]; then
			# Check if this disc is currently being ignored or processing
			isCurrentListItem=`egrep "${eachDisc}:.*" < "$currentItemsList"`
			# Check if action is starting up
			bashPID=`ps uxc | grep -i "sh" | awk '{print $2}'`
			batchRipStatus=0
			for eachPID in $bashPID
			do
				if [ -d "/tmp/batchRipLauncher-${eachPID}"]; then
					batchRipStatus=1
				fi
			done
			# Check if action is currently running
			bashPID=`ps uxc | grep -i "Bash" | awk '{print $2}'`
			for eachPID in $bashPID
			do
				if [ -d "/tmp/batchRip-${eachPID}"]; then
					batchRipStatus=1
				fi
			done
			if [[ "$isCurrentListItem" = "" && "$batchRipStatus" -eq 0 ]]; then
				automator "$HOME/Library/Services/Batch Rip • Batch Rip (Finder).workflow"
			fi
		fi
	done
}

currentItemsList="$HOME/Library/Application Support/Batch Rip/currentItems.txt"

# set delay for more than one drive
deviceCount=`ioreg -iSr -w 0 -c IODVDBlockStorageDevice | grep "Device Characteristics" | sed -e 's|.*"Product Name"="||' -e 's|".*||' | grep -c ""`
if [[ deviceCount -gt 1 ]]; then
	sleep 5
fi
# update current items list
updateCurrentItemsList

# launch batch rip action
batchRipDispatch
